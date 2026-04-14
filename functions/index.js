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
        paymentMode: 'demo',
        paymentGateway: 'bypass',
        paymentReference: 'SKIPPED',
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
        paymentMode: 'demo',
        paymentGateway: 'bypass',
        paymentReference: 'SKIPPED',
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
