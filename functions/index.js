const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// HELPER: Send FCM + Save to Firestore
async function deliverNotification(userId, title, body, type, data = {}) {
  try {
    // 1. Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    const token = userData.fcmToken;
    
    // 2. Send FCM push notification
    if (token) {
      try {
        await admin.messaging().send({
          token: token,
          notification: {
            title: title,
            body: body,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'techxpark_channel',
              sound: 'default',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              icon: 'ic_notification',
              color: '#2845D6',
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                contentAvailable: true,
              }
            }
          },
          data: {
            type: type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            ...Object.fromEntries(
              Object.entries(data).map(([k, v]) => [k, String(v)])
            )
          }
        });
        console.log(`FCM sent to ${userId}`);
      } catch (fcmError) {
        // Token expired or invalid
        if (
            fcmError.code === 'messaging/invalid-registration-token' ||
            fcmError.code === 'messaging/registration-token-not-registered'
        ) {
          // Remove invalid token
          await admin.firestore()
            .collection('users').doc(userId)
            .update({ fcmToken: admin.firestore.FieldValue.delete() });
        }
      }
    }
    
    // 3. Always save to Firestore (shows in NotificationsScreen even if FCM push fails)
    await admin.firestore()
      .collection('notifications')
      .add({
        userId: userId,
        title: title,
        body: body,
        type: type,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: data
      });
      
  } catch (error) {
    console.error('Notification error:', error);
  }
}

// Trigger: onCreate on conversations/{convId}/messages/{msgId}
exports.onNewMessage = functions
  .region('asia-south1')
  .firestore
  .document('conversations/{convId}/messages/{msgId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const convId = context.params.convId;
    
    // Get conversation to find receiver
    const convDoc = await admin.firestore()
      .collection('conversations')
      .doc(convId).get();
    
    if (!convDoc.exists) return;
    const conv = convDoc.data();
    
    // Receiver = participant who is NOT sender
    const receiverId = (conv.participants || []).find(uid => uid !== message.senderId);
    
    if (!receiverId) return;
    
    // Notification title based on role
    let title = message.senderName;
    if (message.senderRole === 'admin') {
      title = '💬 TechXPark Support';
    } else if (message.senderRole === 'owner') {
      title = '🅿️ Parking Manager';
    } else {
      title = `💬 ${message.senderName}`;
    }
    
    await deliverNotification(
      receiverId,
      title,
      message.text,
      'message',
      { conversationId: convId }
    );
  });

exports.onBookingCreated = functions
  .region('asia-south1')
  .firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    
    await deliverNotification(
      booking.userId,
      '🎉 Booking Confirmed!',
      `Slot ${booking.slotId} at ${booking.parkingName} is reserved.`,
      'booking',
      { bookingId: context.params.bookingId }
    );
  });

exports.bookingExpiryReminder = functions
  .region('asia-south1')
  .pubsub
  .schedule('every 2 minutes')
  .onRun(async (context) => {
    const now = new Date();
    const in10Min = new Date(now.getTime() + 10 * 60 * 1000);
    const in12Min = new Date(now.getTime() + 12 * 60 * 1000);
    
    const snap = await admin.firestore()
      .collection('bookings')
      .where('status', '==', 'active')
      .where('endTime', '>=', now)
      .where('endTime', '<=', in12Min)
      .where('expirySent', '!=', true)
      .get();
    
    const batch = admin.firestore().batch();
    
    for (const doc of snap.docs) {
      const booking = doc.data();
      
      await deliverNotification(
        booking.userId,
        '⚠️ Parking Expiring Soon!',
        `Your slot at ${booking.parkingName} expires in 10 minutes. Extend now!`,
        'expiry',
        { bookingId: doc.id }
      );
      
      batch.update(doc.ref, { expirySent: true });
    }
    
    await batch.commit();
  });

exports.onAccessRequestUpdated = functions
  .region('asia-south1')
  .firestore
  .document('access_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Only trigger on status change
    if (before.status === after.status) return;
    
    if (after.status === 'approved') {
      await deliverNotification(
        after.ownerId,
        '🎉 Access Approved!',
        `You now have access to ${after.lotName}. Login to get started!`,
        'access_approved',
        { lotId: after.lotId || '' }
      );
    }
    
    if (after.status === 'rejected') {
      await deliverNotification(
        after.ownerId,
        'Access Request Update',
        `Your request for ${after.lotName} was not approved. Reason: ${after.rejectionReason}`,
        'access_rejected',
        {}
      );
    }
  });

// Called when Super Admin sends notification to all users or a group
exports.broadcastNotification = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    // Verify caller is admin
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const callerDoc = await admin.firestore()
      .collection('users')
      .doc(context.auth.uid).get();
      
    if (!callerDoc.exists || callerDoc.data().role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'Not admin');
    }
    
    const { title, body, type, targetType, targetLotId, targetUserId } = data;
    
    let usersQuery = admin.firestore().collection('users');
    
    // Filter by target
    if (targetType === 'all_users') {
      usersQuery = usersQuery.where('role', '==', 'customer');
    } else if (targetType === 'all_owners') {
      usersQuery = usersQuery.where('role', '==', 'owner');
    } else if (targetType === 'specific_user') {
      usersQuery = usersQuery.where(admin.firestore.FieldPath.documentId(), '==', targetUserId);
    } else if (targetType === 'lot_users') {
      // Get users with bookings at this lot
      const bookings = await admin.firestore()
        .collection('bookings')
        .where('parkingId', '==', targetLotId)
        .get();
      const userIds = [...new Set(bookings.docs.map(d => d.data().userId))];
      // Send to each user individually
      for (const uid of userIds) {
        await deliverNotification(uid, title, body, type);
      }
      return { sent: userIds.length, total: userIds.length };
    }
    
    const users = await usersQuery.get();
    
    // Batch send FCM (max 500 per call)
    const tokens = users.docs
      .map(d => d.data().fcmToken)
      .filter(Boolean);
    
    const chunks = [];
    for (let i = 0; i < tokens.length; i += 500) {
      chunks.push(tokens.slice(i, i + 500));
    }
    
    let successCount = 0;
    for (const chunk of chunks) {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: { title, body },
        android: {
          priority: 'high',
          notification: {
            channelId: 'techxpark_channel',
            sound: 'default',
          }
        },
        data: { type: type || 'broadcast' }
      });
      successCount += result.successCount;
    }
    
    // Save to each user's notifications
    const batch = admin.firestore().batch();
    let batchCount = 0;
    
    for (const userDoc of users.docs) {
      const notifRef = admin.firestore().collection('notifications').doc();
      batch.set(notifRef, {
        userId: userDoc.id,
        title, 
        body, 
        type: type || 'broadcast',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      batchCount++;
      
      // Commit batch if it hits the 500 operation limit
      if (batchCount === 500) {
        await batch.commit();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      await batch.commit();
    }
    
    return { sent: successCount, total: tokens.length };
  });
