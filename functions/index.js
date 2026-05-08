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
    const db = admin.firestore();
    
    await deliverNotification(
      booking.userId,
      '🎉 Booking Confirmed!',
      `Slot ${booking.slotId} at ${booking.parkingName} is reserved.`,
      'booking',
      { bookingId: context.params.bookingId }
    );

    const bookingAction = {
      type: 'open_bookings',
      label: 'View Bookings',
      payload: {
        bookingId: context.params.bookingId,
      },
    };
    const bookingAiMessage = await buildProactiveSupportText({
      db,
      userId: booking.userId,
      userMessage:
        'A parking booking was just created. Send a short confirmation with the most useful next step.',
      fallbackText: `Slot confirmed successfully for ${booking.parkingName}. Your booking is ready to use.`,
    });

    await appendAutoSupportMessage({
      db,
      userId: booking.userId,
      text: bookingAiMessage,
      action: bookingAction,
    });
  });

exports.bookingExpiryReminder = functions
  .region('asia-south1')
  .pubsub
  .schedule('every 2 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const in10Min = new Date(now.getTime() + 10 * 60 * 1000);
    const in12Min = new Date(now.getTime() + 12 * 60 * 1000);
    
    const snap = await db
      .collection('bookings')
      .where('status', 'in', ['active', 'parked', 'requested'])
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

      const expiryAction = await buildExpirySupportAction({
        db,
        bookingId: doc.id,
        booking,
      });
      const expiryAiMessage = await buildProactiveSupportText({
        db,
        userId: booking.userId,
        userMessage:
          'The active parking booking expires in about 10 minutes. Send a short reminder and suggest extending.',
        fallbackText: `Your parking ends in 10 mins at ${booking.parkingName}. Extend now if you need more time.`,
      });

      await appendAutoSupportMessage({
        db,
        userId: booking.userId,
        text: expiryAiMessage,
        action: expiryAction,
      });
      
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

function normalizeStatus(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/-/g, '_')
    .replace(/ /g, '_');
}

function intValue(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }

  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function copyZoneAssignments(raw) {
  const result = {};
  if (!raw || typeof raw !== 'object') return result;

  for (const [key, value] of Object.entries(raw)) {
    result[key] = Array.isArray(value)
      ? value.map(item => intValue(item, 0)).filter(item => item > 0)
      : [];
  }
  return result;
}

function resolveZones(parkingData, totalSlots) {
  const rawZones = Array.isArray(parkingData.zones) && parkingData.zones.length > 0
    ? parkingData.zones
    : [{ name: 'General Zone' }];

  const capacities = rawZones.map(zone =>
    intValue(zone?.capacity ?? zone?.totalSlots ?? zone?.slots, 0)
  );
  const definedTotal = capacities.reduce((sum, value) => sum + value, 0);
  let remaining = Math.max(totalSlots - definedTotal, 0);
  const evenShare = rawZones.length > 0 ? Math.floor(remaining / rawZones.length) : 0;
  let remainder = rawZones.length > 0 ? remaining % rawZones.length : 0;

  return rawZones.map((zone, index) => {
    const name = zone?.name && String(zone.name).trim()
      ? String(zone.name).trim()
      : `Zone ${index + 1}`;
    let capacity = capacities[index];
    if (capacity <= 0) {
      capacity = evenShare + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder -= 1;
    }
    if (capacity <= 0) capacity = 1;

    return {
      key: `zone_${index + 1}`,
      displayName: name,
      code: `Z${index + 1}`,
      capacity,
      index,
    };
  });
}

function pickZone({ zones, preferredZoneName, assignments }) {
  const preferred = String(preferredZoneName || '').trim().toLowerCase();
  const candidates = zones
    .map(zone => ({
      ...zone,
      occupiedSlots: [...(assignments[zone.key] || [])].sort((a, b) => a - b),
    }))
    .filter(zone => zone.occupiedSlots.length < zone.capacity);

  if (candidates.length === 0) return null;

  if (preferred) {
    const exact = candidates.find(
      zone => zone.displayName.toLowerCase() === preferred
    );
    if (exact) return exact;
  }

  candidates.sort((a, b) => {
    const availableDiff =
      (b.capacity - b.occupiedSlots.length) - (a.capacity - a.occupiedSlots.length);
    if (availableDiff !== 0) return availableDiff;
    return a.index - b.index;
  });

  return candidates[0];
}

function findFirstFreeSlot(capacity, occupiedSlots) {
  const occupied = new Set(occupiedSlots);
  for (let slot = 1; slot <= capacity; slot += 1) {
    if (!occupied.has(slot)) return slot;
  }
  return null;
}

function buildTokenNumber(sequence) {
  return `TXP-${String(sequence).padStart(4, '0')}`;
}

function buildEntryCode(bookingId) {
  const compact = String(bookingId || '')
    .replace(/[^A-Za-z0-9]/g, '')
    .toUpperCase();
  if (!compact) return 'TXP000';
  if (compact.length >= 6) return compact.slice(-6);
  return compact.padEnd(6, '0');
}

function buildQrData({ bookingId, userId, parkingId, slotId, entryCode }) {
  return `bookingId=${bookingId};userId=${userId};parkingId=${parkingId};slotId=${slotId};slotNumber=${slotId};entryCode=${entryCode}`;
}

function buildEntryInstructions(zoneName, slotId) {
  return `Proceed to ${zoneName}, follow the smart signage, and park at ${slotId}. Keep your token handy for gate assistance.`;
}

async function buildReleasePlan(tx, bookingData) {
  const parkingId = String(bookingData.parkingId || '');
  if (!parkingId) return null;

  const parkingRef = admin.firestore().collection('parking_locations').doc(parkingId);
  let slotRef = null;
  let releasePhysicalSlot = false;

  const slotId = String(bookingData.slotId || '');
  if (slotId) {
    const candidate = parkingRef.collection('slots').doc(slotId);
    const slotSnap = await tx.get(candidate);
    if (slotSnap.exists) {
      slotRef = candidate;
      releasePhysicalSlot = true;
    }
  }

  let assignments = null;
  let zoneOccupancy = null;
  const zoneKey = String(bookingData.zoneKey || '');
  const zoneSlotNumber = intValue(bookingData.zoneSlotNumber, 0);
  if (zoneKey && zoneSlotNumber > 0) {
    const parkingSnap = await tx.get(parkingRef);
    const parkingData = parkingSnap.data() || {};
    assignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
    const updatedZoneValues = [...(assignments[zoneKey] || [])].filter(
      slot => slot !== zoneSlotNumber
    );
    assignments[zoneKey] = updatedZoneValues;

    zoneOccupancy = {};
    for (const [key, values] of Object.entries(assignments)) {
      zoneOccupancy[key] = values.length;
    }
  }

  return {
    parkingRef,
    slotRef,
    releasePhysicalSlot,
    assignments,
    zoneOccupancy,
  };
}

function applyReleasePlan(tx, releasePlan) {
  if (!releasePlan) return;
  let incrementedParkingCounter = false;

  if (releasePlan.releasePhysicalSlot && releasePlan.slotRef) {
    tx.update(releasePlan.slotRef, {
      taken: false,
      isOccupied: false,
      isReserved: false,
      status: 'available',
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(releasePlan.parkingRef, {
      availableSlots: admin.firestore.FieldValue.increment(1),
      available_slots: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    incrementedParkingCounter = true;
  }

  if (releasePlan.assignments && releasePlan.zoneOccupancy) {
    const updates = {
      virtualSlotAssignments: releasePlan.assignments,
      zoneOccupancy: releasePlan.zoneOccupancy,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };
  }

  return {
    parkingRef,
    slotRef,
    releasePhysicalSlot,
    assignments,
    zoneOccupancy,
  };
}

function applyReleasePlan(tx, releasePlan) {
  if (!releasePlan) return;
  let slotRef = null;
  let releasePhysicalSlot = false;

  if (releasePlan.releasePhysicalSlot && releasePlan.slotRef) {
    tx.update(releasePlan.slotRef, {
      taken: false,
      isOccupied: false,
      isReserved: false,
      status: 'available',
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(releasePlan.parkingRef, {
      availableSlots: admin.firestore.FieldValue.increment(1),
      available_slots: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    incrementedParkingCounter = true;
  }

  if (releasePlan.assignments && releasePlan.zoneOccupancy) {
    const updates = {
      virtualSlotAssignments: releasePlan.assignments,
      zoneOccupancy: releasePlan.zoneOccupancy,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!incrementedParkingCounter) {
      updates.availableSlots = admin.firestore.FieldValue.increment(1);
      updates.available_slots = admin.firestore.FieldValue.increment(1);
    }

    tx.update(releasePlan.parkingRef, updates);
  } else if (!incrementedParkingCounter) {
    tx.update(releasePlan.parkingRef, {
      availableSlots: admin.firestore.FieldValue.increment(1),
      available_slots: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

function ensureAllowedTransition(from, to) {
  const allowedTransitions = {
    upcoming: new Set(['active', 'parked', 'requested', 'completed', 'cancelled']),
    active: new Set(['parked', 'requested', 'completed', 'cancelled']),
    booked: new Set(['parked', 'requested', 'completed', 'cancelled']),
    parked: new Set(['requested', 'completed', 'cancelled']),
    requested: new Set(['completed', 'cancelled']),
    completed: new Set(),
    cancelled: new Set(),
  };

  const allowed = allowedTransitions[from];
  if (!allowed || !allowed.has(to)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `This booking cannot move from ${from} to ${to}.`
    );
  }
}

exports.createSmartParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const parkingId = String(data?.parkingId || '').trim();
    const parkingName = String(data?.parkingName || 'Parking').trim();
    const parkingAddress = String(data?.parkingAddress || '').trim();
    const vehicleNumber = String(data?.vehicleNumber || '')
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '')
      .trim();
    const vehicleType = String(data?.vehicleType || 'Car').trim() || 'Car';
    const preferredZoneName = String(data?.preferredZoneName || '').trim();
    const durationHours = Math.min(Math.max(intValue(data?.durationHours, 8), 1), 24);
    const bookingTimeMs = Number(data?.bookingTimeMs);
    const startTime = Number.isFinite(bookingTimeMs)
      ? new Date(bookingTimeMs)
      : new Date();
    const endTime = new Date(startTime.getTime() + durationHours * 60 * 60 * 1000);

    if (!parkingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Parking location is required.'
      );
    }
    if (!vehicleNumber || vehicleNumber.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Enter a valid vehicle number before booking.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const userRef = db.collection('users').doc(context.auth.uid);
      const parkingRef = db.collection('parking_locations').doc(parkingId);
      const bookingRef = db.collection('bookings').doc();
      const auditRef = db.collection('booking_audit_log').doc();

      const [userSnap, parkingSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(parkingRef),
      ]);

      const userData = userSnap.data() || {};
      if (intValue(userData.activeBookings, 0) > 0) {
        throw new functions.https.HttpsError(
          'already-exists',
          'You already have an active parking booking. Complete it before reserving another slot.'
        );
      }

      if (!parkingSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'This parking location is no longer available.'
        );
      }

      const parkingData = parkingSnap.data() || {};
      if (parkingData.isActive === false) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This parking location is currently unavailable.'
        );
      }

      const totalSlots = intValue(
        parkingData.totalSlots ?? parkingData.total_slots,
        0
      );
      const availableSlots = intValue(
        parkingData.availableSlots ?? parkingData.available_slots,
        0
      );
      if (availableSlots <= 0) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Parking Full. Please try another location or try again later.'
        );
      }

      assignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
      const zones = resolveZones(
        parkingData,
        totalSlots > 0 ? totalSlots : availableSlots
      );
      const selectedZone = pickZone({
        zones,
        preferredZoneName,
        assignments,
      });

      if (!selectedZone) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'All zones are currently full. Please retry in a moment.'
        );
      }

      const slotNumber = findFirstFreeSlot(
        selectedZone.capacity,
        selectedZone.occupiedSlots
      );
      if (!slotNumber) {
        throw new functions.https.HttpsError(
          'aborted',
          'We could not assign a slot right now. Please retry once.'
        );
      }

      const bookingSequence = intValue(parkingData.bookingSequence, 0) + 1;
      const tokenNumber = buildTokenNumber(bookingSequence);
      const entryCode = buildEntryCode(bookingRef.id);
      const slotId = `${selectedZone.code}-S${String(slotNumber).padStart(2, '0')}`;
      const qrData = buildQrData({
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        parkingId,
        slotId,
        entryCode,
      });
      const entryInstructions = buildEntryInstructions(
        selectedZone.displayName,
        slotId
      );

      const updatedAssignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
      const currentZoneSlots = [...(updatedAssignments[selectedZone.key] || [])];
      currentZoneSlots.push(slotNumber);
      currentZoneSlots.sort((a, b) => a - b);
      updatedAssignments[selectedZone.key] = currentZoneSlots;

      zoneOccupancy = {};
      for (const zone of zones) {
        zoneOccupancy[zone.key] = (updatedAssignments[zone.key] || []).length;
      }

      tx.set(bookingRef, {
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        userName: userData.name || 'Customer',
        userEmail: userData.email || '',
        userPhone: userData.phone || '',
        parkingId,
        parkingName,
        parkingAddress,
        latitude: parkingData.latitude ?? null,
        longitude: parkingData.longitude ?? null,
        city: parkingData.city || '',
        vehicle: {
          number: vehicleNumber,
          vehicleNumber: vehicleNumber,
          type: vehicleType,
          vehicleType: vehicleType,
        },
        vehicleNumber,
        vehicleType,
        zone: selectedZone.displayName,
        zoneKey: selectedZone.key,
        zoneCode: selectedZone.code,
        zoneIndex: selectedZone.index,
        slotId,
        slotNumber: slotId,
        zoneSlotNumber: slotNumber,
        tokenNumber,
        status: 'booked',
        bookingType: 'Smart Parking',
        amount: 0,
        amountPaid: 0,
        totalAmount: 0,
        paymentMethod: 'No Payment Required',
        paymentStatus: 'skipped',
        paymentMode: 'not_required',
        paymentGateway: 'none',
        paymentReference: 'NOT_REQUIRED',
        entryCode,
        qrData,
        entryInstructions,
        source: 'quick_booking',
        hours: durationHours,
        durationMinutes: durationHours * 60,
        bookingDate: admin.firestore.Timestamp.fromDate(
          new Date(
            startTime.getFullYear(),
            startTime.getMonth(),
            startTime.getDate()
          )
        ),
        startTime: admin.firestore.Timestamp.fromDate(startTime),
        endTime: admin.firestore.Timestamp.fromDate(endTime),
        extended: false,
        reviewed: false,
        reminderScheduled: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        parkingId,
        action: 'booking_created',
        status: 'booked',
        zone: selectedZone.displayName,
        slotId,
        tokenNumber,
        source: 'quick_booking',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(releasePlan.parkingRef, {
        bookingSequence,
        availableSlots: admin.firestore.FieldValue.increment(-1),
        available_slots: admin.firestore.FieldValue.increment(-1),
        virtualSlotAssignments: updatedAssignments,
        zoneOccupancy,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef,
        {
          activeBookings: admin.firestore.FieldValue.increment(1),
          currentBookingId: bookingRef.id,
        },
        { merge: true }
      );

      return {
        bookingId: bookingRef.id,
        bookingStatus: 'booked',
        zoneName: selectedZone.displayName,
        slotId,
        tokenNumber,
        entryCode,
        qrData,
        entryInstructions,
        startTimeMs: startTime.getTime(),
        endTimeMs: endTime.getTime(),
      };
    });
  });

exports.cancelParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const bookingId = String(data?.bookingId || '').trim();
    if (!bookingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Booking ID is required.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'This booking could not be found.');
      }

      const bookingData = bookingSnap.data() || {};
      if (bookingData.userId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You are not authorized to modify this booking.'
        );
      }

      const currentStatus = normalizeStatus(bookingData.status);
      ensureAllowedTransition(currentStatus, 'cancelled');
      const releasePlan = await buildReleasePlan(tx, bookingData);

      const startTime = bookingData.startTime?.toDate?.();
      if (startTime && ['booked', 'upcoming'].includes(currentStatus)) {
        const cutoff = new Date(startTime.getTime() - 15 * 60 * 1000);
        if (Date.now() > cutoff.getTime()) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Cancellation is not allowed within 15 minutes of the booking start time.'
          );
        }
      }

      tx.update(bookingRef, {
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      applyReleasePlan(tx, releasePlan);
      tx.set(
        db.collection('users').doc(context.auth.uid),
        {
          activeBookings: admin.firestore.FieldValue.increment(-1),
          currentBookingId: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );
      tx.set(db.collection('booking_audit_log').doc(), {
        bookingId,
        userId: context.auth.uid,
        parkingId: bookingData.parkingId || '',
        action: 'booking_cancelled',
        status: 'cancelled',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(db.collection('booking_audit_log').doc(), {
        bookingId,
        userId: context.auth.uid,
        parkingId: bookingData.parkingId || '',
        action: 'booking_cancelled',
        status: 'cancelled',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { message: 'Booking cancelled successfully.' };
    });
  });

exports.completeParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const bookingId = String(data?.bookingId || '').trim();
    if (!bookingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Booking ID is required.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'This booking could not be found.');
      }

      const bookingData = bookingSnap.data() || {};
      if (bookingData.userId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You are not authorized to modify this booking.'
        );
      }

      const currentStatus = normalizeStatus(bookingData.status);
      ensureAllowedTransition(currentStatus, 'completed');
      const releasePlan = await buildReleasePlan(tx, bookingData);

      tx.update(bookingRef, {
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      applyReleasePlan(tx, releasePlan);
      tx.set(
        db.collection('users').doc(bookingData.userId),
        {
          activeBookings: admin.firestore.FieldValue.increment(-1),
          currentBookingId: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );
      tx.set(db.collection('booking_audit_log').doc(), {
        bookingId,
        userId: bookingData.userId,
        parkingId: bookingData.parkingId || '',
        action: 'booking_completed',
        status: 'completed',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(db.collection('booking_audit_log').doc(), {
        bookingId,
        userId: bookingData.userId,
        parkingId: bookingData.parkingId || '',
        action: 'booking_completed',
        status: 'completed',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { message: 'Booking completed successfully.' };
    });
  });

function normalizeStatus(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/-/g, '_')
    .replace(/ /g, '_');
}

function intValue(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }

  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function copyZoneAssignments(raw) {
  const result = {};
  if (!raw || typeof raw !== 'object') return result;

  for (const [key, value] of Object.entries(raw)) {
    result[key] = Array.isArray(value)
      ? value.map(item => intValue(item, 0)).filter(item => item > 0)
      : [];
  }
  return result;
}

function resolveZones(parkingData, totalSlots) {
  const rawZones = Array.isArray(parkingData.zones) && parkingData.zones.length > 0
    ? parkingData.zones
    : [{ name: 'General Zone' }];

  const capacities = rawZones.map(zone =>
    intValue(zone?.capacity ?? zone?.totalSlots ?? zone?.slots, 0)
  );
  const definedTotal = capacities.reduce((sum, value) => sum + value, 0);
  let remaining = Math.max(totalSlots - definedTotal, 0);
  const evenShare = rawZones.length > 0 ? Math.floor(remaining / rawZones.length) : 0;
  let remainder = rawZones.length > 0 ? remaining % rawZones.length : 0;

  return rawZones.map((zone, index) => {
    const name = zone?.name && String(zone.name).trim()
      ? String(zone.name).trim()
      : `Zone ${index + 1}`;
    let capacity = capacities[index];
    if (capacity <= 0) {
      capacity = evenShare + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder -= 1;
    }
    if (capacity <= 0) capacity = 1;

    return {
      key: `zone_${index + 1}`,
      displayName: name,
      code: `Z${index + 1}`,
      capacity,
      index,
    };
  });
}

function pickZone({ zones, preferredZoneName, assignments }) {
  const preferred = String(preferredZoneName || '').trim().toLowerCase();
  const candidates = zones
    .map(zone => ({
      ...zone,
      occupiedSlots: [...(assignments[zone.key] || [])].sort((a, b) => a - b),
    }))
    .filter(zone => zone.occupiedSlots.length < zone.capacity);

  if (candidates.length === 0) return null;

  if (preferred) {
    const exact = candidates.find(
      zone => zone.displayName.toLowerCase() === preferred
    );
    if (exact) return exact;
  }

  candidates.sort((a, b) => {
    const availableDiff =
      (b.capacity - b.occupiedSlots.length) - (a.capacity - a.occupiedSlots.length);
    if (availableDiff !== 0) return availableDiff;
    return a.index - b.index;
  });

  return candidates[0];
}

function findFirstFreeSlot(capacity, occupiedSlots) {
  const occupied = new Set(occupiedSlots);
  for (let slot = 1; slot <= capacity; slot += 1) {
    if (!occupied.has(slot)) return slot;
  }
  return null;
}

function buildTokenNumber(sequence) {
  return `TXP-${String(sequence).padStart(4, '0')}`;
}

function buildEntryCode(bookingId) {
  const compact = String(bookingId || '')
    .replace(/[^A-Za-z0-9]/g, '')
    .toUpperCase();
  if (!compact) return 'TXP000';
  if (compact.length >= 6) return compact.slice(-6);
  return compact.padEnd(6, '0');
}

function buildQrData({ bookingId, userId, parkingId, slotId, entryCode }) {
  return `bookingId=${bookingId};userId=${userId};parkingId=${parkingId};slotId=${slotId};slotNumber=${slotId};entryCode=${entryCode}`;
}

function buildEntryInstructions(zoneName, slotId) {
  return `Proceed to ${zoneName}, follow the smart signage, and park at ${slotId}. Keep your token handy for gate assistance.`;
}

async function buildReleasePlan(tx, bookingData) {
  const parkingId = String(bookingData.parkingId || '');
  if (!parkingId) return null;

  const parkingRef = admin.firestore().collection('parking_locations').doc(parkingId);
  let incrementedParkingCounter = false;

  const slotId = String(bookingData.slotId || '');
  if (slotId) {
    const candidate = parkingRef.collection('slots').doc(slotId);
    const slotSnap = await tx.get(candidate);
    if (slotSnap.exists) {
      slotRef = candidate;
      releasePhysicalSlot = true;
    }
  }

  const zoneKey = String(bookingData.zoneKey || '');
  const zoneSlotNumber = intValue(bookingData.zoneSlotNumber, 0);
  if (zoneKey && zoneSlotNumber > 0) {
    const parkingSnap = await tx.get(parkingRef);
    const parkingData = parkingSnap.data() || {};
    const assignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
    const updatedZoneValues = [...(assignments[zoneKey] || [])].filter(
      slot => slot !== zoneSlotNumber
    );
    assignments[zoneKey] = updatedZoneValues;

    const zoneOccupancy = {};
    for (const [key, values] of Object.entries(assignments)) {
      zoneOccupancy[key] = values.length;
    }

    if (!incrementedParkingCounter) {
      updates.availableSlots = admin.firestore.FieldValue.increment(1);
      updates.available_slots = admin.firestore.FieldValue.increment(1);
    }

    tx.update(releasePlan.parkingRef, updates);
  } else if (!incrementedParkingCounter) {
    tx.update(parkingRef, {
      availableSlots: admin.firestore.FieldValue.increment(1),
      available_slots: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

function ensureAllowedTransition(from, to) {
  const allowedTransitions = {
    upcoming: new Set(['active', 'parked', 'requested', 'completed', 'cancelled']),
    active: new Set(['parked', 'requested', 'completed', 'cancelled']),
    booked: new Set(['parked', 'requested', 'completed', 'cancelled']),
    parked: new Set(['requested', 'completed', 'cancelled']),
    requested: new Set(['completed', 'cancelled']),
    completed: new Set(),
    cancelled: new Set(),
  };

  const allowed = allowedTransitions[from];
  if (!allowed || !allowed.has(to)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `This booking cannot move from ${from} to ${to}.`
    );
  }
}

exports.createSmartParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const parkingId = String(data?.parkingId || '').trim();
    const parkingName = String(data?.parkingName || 'Parking').trim();
    const parkingAddress = String(data?.parkingAddress || '').trim();
    const vehicleNumber = String(data?.vehicleNumber || '')
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '')
      .trim();
    const vehicleType = String(data?.vehicleType || 'Car').trim() || 'Car';
    const preferredZoneName = String(data?.preferredZoneName || '').trim();
    const durationHours = Math.min(Math.max(intValue(data?.durationHours, 8), 1), 24);
    const bookingTimeMs = Number(data?.bookingTimeMs);
    const startTime = Number.isFinite(bookingTimeMs)
      ? new Date(bookingTimeMs)
      : new Date();
    const endTime = new Date(startTime.getTime() + durationHours * 60 * 60 * 1000);

    if (!parkingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Parking location is required.'
      );
    }
    if (!vehicleNumber || vehicleNumber.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Enter a valid vehicle number before booking.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const userRef = db.collection('users').doc(context.auth.uid);
      const parkingRef = db.collection('parking_locations').doc(parkingId);
      const bookingRef = db.collection('bookings').doc();
      const auditRef = db.collection('booking_audit_log').doc();

      const [userSnap, parkingSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(parkingRef),
      ]);

      const userData = userSnap.data() || {};
      if (intValue(userData.activeBookings, 0) > 0) {
        throw new functions.https.HttpsError(
          'already-exists',
          'You already have an active parking booking. Complete it before reserving another slot.'
        );
      }

      if (!parkingSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'This parking location is no longer available.'
        );
      }

      const parkingData = parkingSnap.data() || {};
      if (parkingData.isActive === false) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This parking location is currently unavailable.'
        );
      }

      const totalSlots = intValue(
        parkingData.totalSlots ?? parkingData.total_slots,
        0
      );
      const availableSlots = intValue(
        parkingData.availableSlots ?? parkingData.available_slots,
        0
      );
      if (availableSlots <= 0) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Parking Full. Please try another location or try again later.'
        );
      }

      const assignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
      const zones = resolveZones(
        parkingData,
        totalSlots > 0 ? totalSlots : availableSlots
      );
      const selectedZone = pickZone({
        zones,
        preferredZoneName,
        assignments,
      });

      if (!selectedZone) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'All zones are currently full. Please retry in a moment.'
        );
      }

      const slotNumber = findFirstFreeSlot(
        selectedZone.capacity,
        selectedZone.occupiedSlots
      );
      if (!slotNumber) {
        throw new functions.https.HttpsError(
          'aborted',
          'We could not assign a slot right now. Please retry once.'
        );
      }

      const bookingSequence = intValue(parkingData.bookingSequence, 0) + 1;
      const tokenNumber = buildTokenNumber(bookingSequence);
      const entryCode = buildEntryCode(bookingRef.id);
      const slotId = `${selectedZone.code}-S${String(slotNumber).padStart(2, '0')}`;
      const qrData = buildQrData({
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        parkingId,
        slotId,
        entryCode,
      });
      const entryInstructions = buildEntryInstructions(
        selectedZone.displayName,
        slotId
      );

      const updatedAssignments = copyZoneAssignments(parkingData.virtualSlotAssignments);
      const currentZoneSlots = [...(updatedAssignments[selectedZone.key] || [])];
      currentZoneSlots.push(slotNumber);
      currentZoneSlots.sort((a, b) => a - b);
      updatedAssignments[selectedZone.key] = currentZoneSlots;

      const zoneOccupancy = {};
      for (const zone of zones) {
        zoneOccupancy[zone.key] = (updatedAssignments[zone.key] || []).length;
      }

      tx.set(bookingRef, {
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        userName: userData.name || 'Customer',
        userEmail: userData.email || '',
        userPhone: userData.phone || '',
        parkingId,
        parkingName,
        parkingAddress,
        latitude: parkingData.latitude ?? null,
        longitude: parkingData.longitude ?? null,
        city: parkingData.city || '',
        vehicle: {
          number: vehicleNumber,
          vehicleNumber: vehicleNumber,
          type: vehicleType,
          vehicleType: vehicleType,
        },
        vehicleNumber,
        vehicleType,
        zone: selectedZone.displayName,
        zoneKey: selectedZone.key,
        zoneCode: selectedZone.code,
        zoneIndex: selectedZone.index,
        slotId,
        slotNumber: slotId,
        zoneSlotNumber: slotNumber,
        tokenNumber,
        status: 'booked',
        bookingType: 'Smart Parking',
        amount: 0,
        amountPaid: 0,
        totalAmount: 0,
        paymentMethod: 'No Payment Required',
        paymentStatus: 'skipped',
        paymentMode: 'not_required',
        paymentGateway: 'none',
        paymentReference: 'NOT_REQUIRED',
        entryCode,
        qrData,
        entryInstructions,
        source: 'quick_booking',
        hours: durationHours,
        durationMinutes: durationHours * 60,
        bookingDate: admin.firestore.Timestamp.fromDate(
          new Date(
            startTime.getFullYear(),
            startTime.getMonth(),
            startTime.getDate()
          )
        ),
        startTime: admin.firestore.Timestamp.fromDate(startTime),
        endTime: admin.firestore.Timestamp.fromDate(endTime),
        extended: false,
        reviewed: false,
        reminderScheduled: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(auditRef, {
        bookingId: bookingRef.id,
        userId: context.auth.uid,
        parkingId,
        action: 'booking_created',
        status: 'booked',
        zone: selectedZone.displayName,
        slotId,
        tokenNumber,
        source: 'quick_booking',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(parkingRef, {
        bookingSequence,
        availableSlots: admin.firestore.FieldValue.increment(-1),
        available_slots: admin.firestore.FieldValue.increment(-1),
        virtualSlotAssignments: updatedAssignments,
        zoneOccupancy,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef,
        {
          activeBookings: admin.firestore.FieldValue.increment(1),
          currentBookingId: bookingRef.id,
        },
        { merge: true }
      );

      return {
        bookingId: bookingRef.id,
        bookingStatus: 'booked',
        zoneName: selectedZone.displayName,
        slotId,
        tokenNumber,
        entryCode,
        qrData,
        entryInstructions,
        startTimeMs: startTime.getTime(),
        endTimeMs: endTime.getTime(),
      };
    });
  });

exports.cancelParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const bookingId = String(data?.bookingId || '').trim();
    if (!bookingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Booking ID is required.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'This booking could not be found.');
      }

      const bookingData = bookingSnap.data() || {};
      if (bookingData.userId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You are not authorized to modify this booking.'
        );
      }

      const currentStatus = normalizeStatus(bookingData.status);
      ensureAllowedTransition(currentStatus, 'cancelled');

      const startTime = bookingData.startTime?.toDate?.();
      if (startTime && ['booked', 'upcoming'].includes(currentStatus)) {
        const cutoff = new Date(startTime.getTime() - 15 * 60 * 1000);
        if (Date.now() > cutoff.getTime()) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Cancellation is not allowed within 15 minutes of the booking start time.'
          );
        }
      }

      tx.update(bookingRef, {
        status: 'cancelled',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      applyReleasePlan(tx, releasePlan);
      tx.set(
        db.collection('users').doc(context.auth.uid),
        {
          activeBookings: admin.firestore.FieldValue.increment(-1),
          currentBookingId: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );

      return { message: 'Booking cancelled successfully.' };
    });
  });

exports.completeParkingBooking = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const bookingId = String(data?.bookingId || '').trim();
    if (!bookingId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Booking ID is required.'
      );
    }

    const db = admin.firestore();
    return db.runTransaction(async tx => {
      const bookingRef = db.collection('bookings').doc(bookingId);
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'This booking could not be found.');
      }

      const bookingData = bookingSnap.data() || {};
      if (bookingData.userId !== context.auth.uid) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'You are not authorized to modify this booking.'
        );
      }

      const currentStatus = normalizeStatus(bookingData.status);
      ensureAllowedTransition(currentStatus, 'completed');

      tx.update(bookingRef, {
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      applyReleasePlan(tx, releasePlan);
      tx.set(
        db.collection('users').doc(bookingData.userId),
        {
          activeBookings: admin.firestore.FieldValue.increment(-1),
          currentBookingId: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );

      return { message: 'Booking completed successfully.' };
    });
  });

// ═══════════════════════════════════════════════════════════════════
// GODREJ BKC — Vehicle Retrieval ETA System
// ═══════════════════════════════════════════════════════════════════

// 1. Calculate ETA & Create Retrieval Request
exports.createRetrievalRequest = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    const { zoneId, employeePhone, employeeName, vehicleNumber, vehicleModel } = data;

    if (!zoneId || !employeePhone || !employeeName || !vehicleNumber) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: zoneId, employeePhone, employeeName, vehicleNumber'
      );
    }

    const db = admin.firestore();

    // Get zone config
    const zoneDoc = await db.collection('godrej_zones').doc(zoneId).get();
    if (!zoneDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Zone not found');
    }
    const zone = zoneDoc.data();
    const baseEta = zone.baseEtaMinutes || 15;
    const activeLifters = zone.activeLifters || 1;

    // Get queued requests in this zone
    const queuedSnap = await db.collection('godrej_requests')
      .where('zoneId', '==', zoneId)
      .where('status', 'in', ['queued', 'in_process'])
      .orderBy('requestedAt')
      .get();

    const queuedRequests = queuedSnap.docs;
    const queuePosition = queuedRequests.length + 1;

    // Calculate ETA: batchesAhead = ceil(requestsAhead / lifters)
    const requestsAhead = queuePosition - 1;
    const batchesAhead = activeLifters > 0
      ? Math.ceil(requestsAhead / activeLifters)
      : requestsAhead;
    const etaMinutes = baseEta + (batchesAhead * baseEta);

    // Assign to lifter with least load
    const liftersSnap = await db.collection('godrej_lifters')
      .where('zoneId', '==', zoneId)
      .where('isActive', '==', true)
      .get();

    const lifterLoads = {};
    liftersSnap.docs.forEach(d => {
      if (d.data().status !== 'breakdown') {
        lifterLoads[d.id] = 0;
      }
    });
    queuedRequests.forEach(r => {
      const lid = r.data().assignedLifterId;
      if (lid && lifterLoads[lid] !== undefined) {
        lifterLoads[lid] = (lifterLoads[lid] || 0) + 1;
      }
    });

    const assignedLifterId = Object.entries(lifterLoads)
      .sort((a, b) => a[1] - b[1])[0]?.[0] || null;

    const estimatedReadyTime = new Date(Date.now() + etaMinutes * 60000);

    const requestToken = Math.random().toString(36).substr(2, 9) + Date.now().toString(36);

    // Create request document
    const reqRef = await db.collection('godrej_requests').add({
      requestToken,
      employeeName,
      employeePhone,
      vehicleNumber,
      vehicleModel: vehicleModel || '',
      zoneId,
      assignedLifterId,
      queuePosition,
      status: 'queued',
      etaMinutes,
      estimatedReadyTime: admin.firestore.Timestamp.fromDate(estimatedReadyTime),
      requestedAt: admin.firestore.FieldValue.serverTimestamp(),
      processingStartedAt: null,
      readyNotifiedAt: null,
      collectedAt: null,
      reParkedAt: null,
      notCollectedDeadline: null,
      smsDelivered: false,
      totalTurnaroundMinutes: null,
      operatorId: null,
      notes: ''
    });

    // Generate SMS message
    const timeStr = estimatedReadyTime.toLocaleTimeString('en-IN', {
      hour: '2-digit', minute: '2-digit', hour12: true, timeZone: 'Asia/Kolkata'
    });
    const trackingUrl = `https://techxpark-67c25.web.app/track/${reqRef.id}`;
    const smsMessage = `Dear ${employeeName}, your vehicle ${vehicleNumber} retrieval request has been queued. Estimated ready time: ${timeStr}. Track here: ${trackingUrl}`;

    // Save SMS notification
    await db.collection('godrej_notifications').add({
      requestId: reqRef.id,
      employeePhone,
      type: 'request_created',
      message: smsMessage,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      delivered: false
    });

    return {
      requestId: reqRef.id,
      requestToken,
      queuePosition,
      etaMinutes,
      estimatedReadyTime: estimatedReadyTime.toISOString(),
      trackingUrl,
      assignedLifterId
    };
  });

// 2. Mark Vehicle Ready + Notify
exports.markVehicleReady = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const { requestId } = data;
    if (!requestId) {
      throw new functions.https.HttpsError('invalid-argument', 'requestId is required');
    }

    const db = admin.firestore();

    const settingsDoc = await db.collection('godrej_settings').doc('global').get();
    const timeout = settingsDoc.exists
      ? (settingsDoc.data().nonCollectionTimeoutMinutes || 15)
      : 15;

    const deadline = new Date(Date.now() + timeout * 60000);

    await db.collection('godrej_requests').doc(requestId).update({
      status: 'ready',
      readyNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      notCollectedDeadline: admin.firestore.Timestamp.fromDate(deadline),
      operatorId: context.auth.uid
    });

    // Get request data for SMS
    const reqDoc = await db.collection('godrej_requests').doc(requestId).get();
    const req = reqDoc.data();

    // Save ready notification
    await db.collection('godrej_notifications').add({
      requestId,
      employeePhone: req.employeePhone,
      type: 'ready',
      message: `✅ Your vehicle ${req.vehicleNumber} is ready for pickup! Please collect within ${timeout} minutes. If not collected, it will be returned to the parking zone.`,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      delivered: false
    });

    return { success: true };
  });

// 3. Auto Non-Collection Handler (runs every 1 minute)
exports.checkGodrejNonCollection = functions
  .region('asia-south1')
  .pubsub
  .schedule('every 1 minutes')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection('godrej_requests')
      .where('status', '==', 'ready')
      .where('notCollectedDeadline', '<=', now)
      .get();

    if (snap.empty) return null;

    const batch = db.batch();

    for (const doc of snap.docs) {
      const data = doc.data();
      const requestedAt = data.requestedAt?.toDate();
      const reParkedAt = new Date();
      const turnaround = requestedAt
        ? Math.round((reParkedAt - requestedAt) / 60000)
        : null;

      batch.update(doc.ref, {
        status: 're_parked',
        reParkedAt: admin.firestore.FieldValue.serverTimestamp(),
        totalTurnaroundMinutes: turnaround
      });

      // Save re-park notification
      await db.collection('godrej_notifications').add({
        requestId: doc.id,
        employeePhone: data.employeePhone,
        type: 're_parked',
        message: `Your vehicle ${data.vehicleNumber} was not collected in time and has been returned to parking. Please raise a new request.`,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        delivered: false
      });
    }

    await batch.commit();
    return null;
  });

exports.verifyVehicleInfo = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const vehicleNumber = String(data?.vehicleNumber || '')
      .toUpperCase()
      .replace(/[^A-Z0-9]/g, '')
      .trim();
    if (vehicleNumber.length < 6) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Enter a valid vehicle number.'
      );
    }

    const apiKey =
      process.env.RAPIDAPI_KEY ||
      (functions.config().rapidapi && functions.config().rapidapi.key) ||
      '';
    if (!apiKey) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Vehicle verification is not configured.'
      );
    }

    const host =
      process.env.RAPIDAPI_RTO_HOST ||
      'rto-vehicle-information-verification-india.p.rapidapi.com';
    const response = await fetch(`https://${host}/api/v1/vehicle_info`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-RapidAPI-Key': apiKey,
        'X-RapidAPI-Host': host,
      },
      body: JSON.stringify({
        reg_no: vehicleNumber,
        consent: 'Y',
        consent_text: 'I hereby declare my consent',
      }),
    });

    if (!response.ok) {
      throw new functions.https.HttpsError(
        'unavailable',
        'Vehicle verification is temporarily unavailable.'
      );
    }

    const payload = await response.json();
    return {result: payload.result || null};
  });

const SUPPORT_CHAT_ID = 'ai_support';
const SUPPORT_SYSTEM_PROMPT = `You are TechXPark AI Assistant.

You help users with:
- Parking bookings
- Slot availability
- Payment issues
- Navigation
- Extensions

Rules:
- Be short and helpful
- Give direct answers
- Suggest actions when useful
- Respond with JSON only
- Never say "contact support"
- Assume real-time parking context
- Do not invent bookings, payments, slots, prices, or times

Response JSON schema:
{
  "text": "short helpful response",
  "actions": [
    {
      "type": "extend_booking|navigate_parking|open_wallet|open_bookings",
      "label": "button label",
      "payload": {}
    }
  ]
}

Tone:
- Friendly
- Smart
- Professional`;

function supportChatRef(db, userId, chatId = SUPPORT_CHAT_ID) {
  return db.collection('users').doc(userId).collection('support_chats').doc(chatId);
}

function supportMessagesRef(db, userId, chatId = SUPPORT_CHAT_ID) {
  return supportChatRef(db, userId, chatId).collection('messages');
}

function serializeTimestamp(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  return null;
}

function readNumber(value, fallback = null) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function chatPreview(text) {
  const normalized = String(text || '').trim();
  if (!normalized) return '';
  return normalized.length > 160
    ? `${normalized.slice(0, 157).trimEnd()}...`
    : normalized;
}

async function saveSupportChatMessage({
  db,
  userId,
  chatId = SUPPORT_CHAT_ID,
  text,
  sender,
  action = null,
  actions = null,
  incrementUnread = false,
  isSystem = false,
}) {
  const safeText = chatPreview(text);
  if (!safeText) return null;

  const chatRef = supportChatRef(db, userId, chatId);
  const messageRef = supportMessagesRef(db, userId, chatId).doc();
  const batch = db.batch();

  const messagePayload = {
    text: safeText,
    sender,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    isRead: sender === 'user',
    isSystem,
  };
  const safeActions = normalizeSupportActions(actions || (action ? [action] : []));
  if (safeActions.length > 0) {
    messagePayload.actions = safeActions;
    messagePayload.action = safeActions[0];
  }

  const chatPayload = {
    title: 'AI Support',
    assistantType: 'ai',
    status: 'open',
    lastMessage: safeText,
    lastSender: sender,
    lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (incrementUnread) {
    chatPayload.unreadCount = admin.firestore.FieldValue.increment(1);
  } else if (sender === 'user') {
    chatPayload.unreadCount = 0;
  }

  batch.set(chatRef, chatPayload, {merge: true});
  batch.set(messageRef, messagePayload);
  await batch.commit();
  return messageRef.id;
}

async function appendAutoSupportMessage({
  db,
  userId,
  text,
  action = null,
  chatId = SUPPORT_CHAT_ID,
}) {
  if (!userId || !text) return null;
  return saveSupportChatMessage({
    db,
    userId,
    chatId,
    text,
    sender: 'ai',
    actions: action ? [action] : [],
    incrementUnread: true,
    isSystem: true,
  });
}

function bookingStatusPriority(status) {
  switch (normalizeStatus(status)) {
    case 'requested':
    case 'parked':
    case 'active':
    case 'booked':
      return 0;
    case 'upcoming':
      return 1;
    default:
      return 2;
  }
}

async function buildAiSupportContext(db, userId) {
  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  const userData = userSnap.data() || {};

  const bookingsSnap = await db
    .collection('bookings')
    .where('userId', '==', userId)
    .where('status', 'in', ['upcoming', 'active', 'booked', 'parked', 'requested'])
    .get();

  const bookingDocs = bookingsSnap.docs.slice().sort((a, b) => {
    const dataA = a.data() || {};
    const dataB = b.data() || {};
    const statusScore = bookingStatusPriority(dataA.status) - bookingStatusPriority(dataB.status);
    if (statusScore !== 0) return statusScore;
    const timeA =
      dataA.updatedAt?.toMillis?.() ||
      dataA.startTime?.toMillis?.() ||
      dataA.createdAt?.toMillis?.() ||
      0;
    const timeB =
      dataB.updatedAt?.toMillis?.() ||
      dataB.startTime?.toMillis?.() ||
      dataB.createdAt?.toMillis?.() ||
      0;
    return timeB - timeA;
  });

  const bookingDoc = bookingDocs[0] || null;
  const bookingData = bookingDoc ? bookingDoc.data() || {} : null;
  let parkingData = null;

  if (bookingData?.parkingId) {
    const parkingSnap = await db.collection('parking_locations').doc(String(bookingData.parkingId)).get();
    parkingData = parkingSnap.data() || null;
  }

  return {
    user: {
      userId,
      name: userData.name || userData.displayName || 'User',
      email: userData.email || '',
    },
    booking: bookingData
      ? {
          bookingId: bookingDoc.id,
          status: bookingData.status || '',
          parkingId: bookingData.parkingId || '',
          parkingName: bookingData.parkingName || '',
          slotId: bookingData.slotId || '',
          slotNumber: bookingData.slotNumber || bookingData.slotId || '',
          floorIndex: intValue(bookingData.floorIndex, 0),
          startTime: serializeTimestamp(bookingData.startTime),
          endTime: serializeTimestamp(bookingData.endTime),
          paymentStatus: bookingData.paymentStatus || 'unknown',
          paymentMethod: bookingData.paymentMethod || '',
          amountPaid: readNumber(bookingData.amountPaid, 0),
          extended: Boolean(bookingData.extended),
        }
      : null,
    parking: parkingData
      ? {
          parkingId: bookingData?.parkingId || '',
          name: parkingData.name || bookingData?.parkingName || 'Parking',
          address: parkingData.address || '',
          latitude: readNumber(parkingData.latitude ?? parkingData.lat),
          longitude: readNumber(parkingData.longitude ?? parkingData.lng),
          availableSlots: intValue(
            parkingData.availableSlots ?? parkingData.available_slots,
            0
          ),
          totalSlots: intValue(parkingData.totalSlots ?? parkingData.total_slots, 0),
          pricePerHour: readNumber(
            parkingData.price_per_hour ?? parkingData.pricePerHour ?? parkingData.price,
            0
          ),
        }
      : null,
  };
}

async function getSupportHistory(db, userId, chatId = SUPPORT_CHAT_ID) {
  const snapshot = await supportMessagesRef(db, userId, chatId)
    .orderBy('timestamp', 'desc')
    .limit(8)
    .get();

  return snapshot.docs
    .map((doc) => doc.data() || {})
    .reverse()
    .map((data) => ({
      sender: data.sender || 'ai',
      text: String(data.text || '').trim(),
    }))
    .filter((entry) => entry.text);
}

function detectSupportAction(userMessage, context) {
  const normalized = String(userMessage || '').trim().toLowerCase();
  const booking = context.booking;
  const parking = context.parking;

  if (
    /(navigate|direction|route|go to parking|take me|open maps)/.test(normalized) &&
    parking &&
    parking.latitude != null &&
    parking.longitude != null
  ) {
    return {
      type: 'navigate_parking',
      label: 'Open Maps',
      payload: {
        parkingName: parking.name || booking?.parkingName || 'Parking',
        latitude: parking.latitude,
        longitude: parking.longitude,
      },
    };
  }

  if (/(extend|more time|increase time|extra hour|extend parking)/.test(normalized) && booking) {
    return {
      type: 'extend_booking',
      label: 'Tap Extend Booking',
      payload: {
        bookingId: booking.bookingId,
        slotId: booking.slotId || '',
        floorIndex: booking.floorIndex || 0,
        startTime: booking.startTime,
        endTime: booking.endTime,
        parking: {
          id: booking.parkingId || '',
          name: booking.parkingName || parking?.name || 'Parking',
          latitude: parking?.latitude ?? null,
          longitude: parking?.longitude ?? null,
          address: parking?.address || '',
        },
      },
    };
  }

  if (/(payment|upi|card|refund|charged|wallet|failed)/.test(normalized)) {
    return {
      type: 'open_wallet',
      label: 'Open Wallet',
      payload: {},
    };
  }

  if (/(booking|slot|ticket|active booking|my booking)/.test(normalized)) {
    return {
      type: 'open_bookings',
      label: 'View Bookings',
      payload: {},
    };
  }

  return null;
}

function normalizeSupportActions(rawActions) {
  const actions = Array.isArray(rawActions) ? rawActions : [];
  const allowedTypes = new Set([
    'extend_booking',
    'navigate_parking',
    'open_wallet',
    'open_bookings',
  ]);

  return actions
    .map((action) => {
      if (!action || typeof action !== 'object') return null;
      let type = String(action.type || '').trim();
      if (type === 'navigate') type = 'navigate_parking';
      if (type === 'retry_payment') type = 'open_wallet';
      const label = chatPreview(action.label || '');
      if (!allowedTypes.has(type) || !label) return null;
      const payload =
        action.payload && typeof action.payload === 'object' && !Array.isArray(action.payload)
          ? action.payload
          : {};
      return {type, label, payload};
    })
    .filter(Boolean)
    .slice(0, 3);
}

function mergeSupportActions(aiActions, deterministicAction) {
  const merged = normalizeSupportActions(aiActions);
  if (deterministicAction) {
    const normalized = normalizeSupportActions([deterministicAction]);
    for (const action of normalized) {
      if (!merged.some((item) => item.type === action.type)) {
        merged.unshift(action);
      }
    }
  }
  return merged.slice(0, 3);
}

async function buildExpirySupportAction({db, bookingId, booking}) {
  if (!booking) return null;

  let parking = null;
  if (booking.parkingId) {
    const parkingSnap = await db
      .collection('parking_locations')
      .doc(String(booking.parkingId))
      .get();
    parking = parkingSnap.data() || null;
  }

  return {
    type: 'extend_booking',
    label: 'Tap Extend Booking',
    payload: {
      bookingId,
      slotId: booking.slotId || '',
      floorIndex: intValue(booking.floorIndex, 0),
      startTime: serializeTimestamp(booking.startTime),
      endTime: serializeTimestamp(booking.endTime),
      parking: {
        id: booking.parkingId || '',
        name: booking.parkingName || parking?.name || 'Parking',
        latitude: readNumber(parking?.latitude ?? parking?.lat),
        longitude: readNumber(parking?.longitude ?? parking?.lng),
        address: parking?.address || '',
      },
    },
  };
}

function extractGeminiText(payload) {
  return (
    payload?.candidates?.[0]?.content?.parts
      ?.map((part) => part?.text || '')
      .join('')
      .trim() || ''
  );
}

function stripJsonFence(text) {
  const trimmed = String(text || '').trim();
  if (!trimmed.startsWith('```')) return trimmed;
  return trimmed
    .replace(/^```(?:json)?/i, '')
    .replace(/```$/i, '')
    .trim();
}

function parseAiSupportJson(text) {
  const cleaned = stripJsonFence(text);
  try {
    const parsed = JSON.parse(cleaned);
    return {
      text: chatPreview(parsed.text || ''),
      actions: normalizeSupportActions(parsed.actions),
    };
  } catch (error) {
    console.error('Gemini support returned invalid JSON:', cleaned);
    return {
      text: chatPreview(cleaned),
      actions: [],
    };
  }
}

async function requestGeminiSupportReply({userMessage, context, history}) {
  const apiKey =
    process.env.GEMINI_API_KEY ||
    (functions.config().gemini && functions.config().gemini.key) ||
    '';
  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Gemini API key is not configured.'
    );
  }

  const model = process.env.GEMINI_SUPPORT_MODEL || 'gemini-1.5-flash';
  const prompt = [
    SUPPORT_SYSTEM_PROMPT,
    '',
    'Current TechXPark context:',
    JSON.stringify(context, null, 2),
    '',
    'Recent support chat history:',
    history.length
      ? history.map((entry) => `${entry.sender}: ${entry.text}`).join('\n')
      : 'No prior messages.',
    '',
    `Latest user message: ${userMessage}`,
    '',
    'Return JSON only. Keep text under 80 words. Use actions only from the schema.',
  ].join('\n');

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [{text: prompt}],
        },
      ],
      generationConfig: {
        temperature: 0.35,
        maxOutputTokens: 320,
        responseMimeType: 'application/json',
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Gemini support request failed:', errorText);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate AI support response.'
    );
  }

  const payload = await response.json();
  const text = extractGeminiText(payload);
  if (!text) {
    throw new functions.https.HttpsError(
      'internal',
      'AI support returned an empty response.'
    );
  }
  return parseAiSupportJson(text);
}

async function buildProactiveSupportText({db, userId, userMessage, fallbackText}) {
  try {
    const context = await buildAiSupportContext(db, userId);
    const response = await requestGeminiSupportReply({
      userMessage,
      context,
      history: [],
    });
    return chatPreview(response.text) || fallbackText;
  } catch (error) {
    console.error('Proactive Gemini support error:', error);
    return fallbackText;
  }
}

exports.sendAiSupportMessage = functions
  .region('asia-south1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Please sign in to continue.'
      );
    }

    const userId = context.auth.uid;
    const chatId = String(data?.chatId || SUPPORT_CHAT_ID).trim() || SUPPORT_CHAT_ID;
    const message = String(data?.message || '').trim();
    if (!message) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message text is required.'
      );
    }

    const db = admin.firestore();

    await saveSupportChatMessage({
      db,
      userId,
      chatId,
      text: message,
      sender: 'user',
      incrementUnread: false,
    });

    const supportContext = await buildAiSupportContext(db, userId);
    const history = await getSupportHistory(db, userId, chatId);
    const deterministicAction = detectSupportAction(message, supportContext);
    let aiResponse;
    try {
      aiResponse = await requestGeminiSupportReply({
        userMessage: message,
        context: supportContext,
        history,
      });
    } catch (error) {
      console.error('Gemini support error:', error);
      aiResponse = {
        text: "Something went wrong. Please try again.",
        actions: [],
      };
    }
    const actions = mergeSupportActions(aiResponse.actions, deterministicAction);
    const aiReply =
      chatPreview(aiResponse.text) ||
      "I checked your parking context. What would you like to do next?";

    console.log('Support AI user:', message);
    console.log('AI RESPONSE:', JSON.stringify({text: aiReply, actions}));

    await saveSupportChatMessage({
      db,
      userId,
      chatId,
      text: aiReply,
      sender: 'ai',
      actions,
      incrementUnread: true,
    });

    return {
      text: aiReply,
      actions,
      reply: aiReply,
      action: actions[0] || null,
      chatId,
    };
  });
