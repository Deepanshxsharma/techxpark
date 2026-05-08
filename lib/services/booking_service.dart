import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'abuse_monitor.dart';
import 'booking_exceptions.dart';
import 'booking_status_helper.dart';

// ─── RESULT TYPES ───────────────────────────────────────────────────────────

class BookingCreationResult {
  final String bookingId;
  final String bookingStatus;
  final String paymentStatus;
  final String paymentMethod;
  final String entryCode;
  final String qrData;

  const BookingCreationResult({
    required this.bookingId,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.entryCode,
    required this.qrData,
  });
}

class SmartParkingBookingResult {
  final String bookingId;
  final String bookingStatus;
  final String zoneName;
  final String slotId;
  final String tokenNumber;
  final String entryCode;
  final String qrData;
  final String entryInstructions;
  final DateTime startTime;
  final DateTime endTime;

  const SmartParkingBookingResult({
    required this.bookingId,
    required this.bookingStatus,
    required this.zoneName,
    required this.slotId,
    required this.tokenNumber,
    required this.entryCode,
    required this.qrData,
    required this.entryInstructions,
    required this.startTime,
    required this.endTime,
  });
}

// ─── BOOKING SERVICE ────────────────────────────────────────────────────────

class BookingService {
  BookingService._();
  static final instance = BookingService._();

  final _fs = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _audit = AbuseMonitor.instance;

  User? get _user => FirebaseAuth.instance.currentUser;

  static const Map<String, List<String>> _allowedTransitions = {
    'upcoming': ['active', 'cancelled', 'parked'],
    'active': ['parked', 'cancelled', 'completed', 'requested'],
    'booked': ['parked', 'cancelled', 'completed', 'requested'],
    'parked': ['requested', 'completed'],
    'requested': ['completed'],
  };

  // ─── CREATE (regular booking) ───────────────────────────────────────────

  Future<BookingCreationResult> createBooking({
    required String parkingId,
    required String parkingName,
    required String parkingAddress,
    required String slotId,
    required String slotNumber,
    required int floorIndex,
    required DateTime startTime,
    required DateTime endTime,
    required double ratePerHour,
    required double baseFee,
    required double durationCharge,
    required double serviceFee,
    required double taxAmount,
    required double discountAmount,
    required double totalAmount,
    required String bookingType,
    required Map<String, dynamic> vehicle,
    required String paymentMethod,
    required String paymentStatus,
    required String paymentMode,
    required String paymentGateway,
    required String paymentReference,
  }) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    await _guardAgainstSuspiciousActivity(
      userId: user.uid,
      parkingId: parkingId,
      slotId: slotId,
    );

    final hours = endTime.difference(startTime).inMinutes / 60;
    final isUpcomingBooking = startTime.isAfter(DateTime.now());

    try {
      return await _fs.runTransaction<BookingCreationResult>((tx) async {
        final userRef = _fs.collection('users').doc(user.uid);
        final parkingRef = _fs.collection('parking_locations').doc(parkingId);
        final slotRef = parkingRef.collection('slots').doc(slotId);

        // ── Check slot conflicts ────────────────────────────────────────
        final slotBookings = await _fs
            .collection('bookings')
            .where('parkingId', isEqualTo: parkingId)
            .where('slotId', isEqualTo: slotId)
            .where('status', whereIn: BookingStatusHelper.blockingStatuses)
            .get();

        for (final doc in slotBookings.docs) {
          final d = doc.data();
          final existStart = (d['startTime'] as Timestamp).toDate();
          final existEnd = (d['endTime'] as Timestamp).toDate();

          if (startTime.isBefore(existEnd) && endTime.isAfter(existStart)) {
            throw SlotAlreadyBookedException(
              conflictStart: existStart,
              conflictEnd: existEnd,
            );
          }
        }

        // ── Check user overlaps ─────────────────────────────────────────
        final userBookings = await _fs
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .where('status', whereIn: BookingStatusHelper.blockingStatuses)
            .get();

        for (final doc in userBookings.docs) {
          final d = doc.data();
          final existStart = (d['startTime'] as Timestamp).toDate();
          final existEnd = (d['endTime'] as Timestamp).toDate();

          if (startTime.isBefore(existEnd) && endTime.isAfter(existStart)) {
            throw UserBookingOverlapException(existingBookingId: doc.id);
          }
        }

        // ── Get user data ───────────────────────────────────────────────
        final bookingRef = _fs.collection('bookings').doc();
        final userSnap = await tx.get(userRef);
        final userData = userSnap.data() ?? {};
        final userName =
            (userData['name'] as String?) ?? user.displayName ?? 'Customer';
        final userEmail = (userData['email'] as String?) ?? user.email ?? '';
        final userPhone = (userData['phone'] as String?) ?? '';

        // ── Validate slot ───────────────────────────────────────────────
        final slotSnap = await tx.get(slotRef);
        if (!slotSnap.exists) {
          throw BookingException.generic(
            'Slot unavailable',
            'This parking slot no longer exists. Please choose another slot.',
          );
        }

        final slotData = slotSnap.data() ?? {};
        if (_slotIsUnavailable(slotData)) {
          throw BookingException.generic(
            'Slot unavailable',
            'This slot has just been reserved or occupied. Please pick a different slot.',
          );
        }

        // ── Resolve payment fields ──────────────────────────────────────
        final bookingStatus = isUpcomingBooking ? 'upcoming' : 'active';
        final resolvedPaymentMethod = paymentMethod.trim().isEmpty
            ? 'Pay at Parking'
            : paymentMethod.trim();
        final resolvedPaymentStatus = paymentStatus.trim().isEmpty
            ? 'pending'
            : paymentStatus.trim();
        final resolvedPaymentMode = paymentMode.trim().isEmpty
            ? 'offline'
            : paymentMode.trim();
        final resolvedPaymentGateway = paymentGateway.trim().isEmpty
            ? 'manual_collection'
            : paymentGateway.trim();
        final paymentCaptured = _paymentIsCaptured(resolvedPaymentStatus);
        final entryCode = _buildEntryCode(bookingRef.id);
        final qrData = _buildQrData(
          bookingId: bookingRef.id,
          userId: user.uid,
          parkingId: parkingId,
          slotId: slotId,
          slotNumber: slotNumber,
          entryCode: entryCode,
        );
        final resolvedPaymentReference = paymentReference.trim().isEmpty
            ? _buildPaymentReference(
                bookingId: bookingRef.id,
                paymentMethod: resolvedPaymentMethod,
              )
            : paymentReference.trim();

        // ── Write booking ───────────────────────────────────────────────
        tx.set(bookingRef, {
          'bookingId': bookingRef.id,
          'userId': user.uid,
          'userName': userName,
          'userEmail': userEmail,
          'userPhone': userPhone,
          'parkingId': parkingId,
          'parkingName': parkingName,
          'parkingAddress': parkingAddress,
          'vehicle': vehicle,
          'vehicleNumber':
              vehicle['number']?.toString() ??
              vehicle['vehicleNumber']?.toString() ??
              '',
          'vehicleType':
              vehicle['type']?.toString() ??
              vehicle['vehicleType']?.toString() ??
              'Car',
          'vehicleColor': vehicle['color']?.toString() ?? '',
          'rtoVerified': vehicle['rtoVerified'] == true,
          'slotId': slotId,
          'slotNumber': slotNumber,
          'floor': floorIndex,
          'bookingDate': Timestamp.fromDate(
            DateTime(startTime.year, startTime.month, startTime.day),
          ),
          'startTime': Timestamp.fromDate(startTime),
          'endTime': Timestamp.fromDate(endTime),
          'hours': hours.ceil(),
          'durationMinutes': endTime.difference(startTime).inMinutes,
          'amount': totalAmount,
          'amountPaid': paymentCaptured ? totalAmount : 0,
          'totalAmount': totalAmount,
          'pricePerHour': ratePerHour,
          'baseFee': baseFee,
          'durationCharge': durationCharge,
          'serviceFee': serviceFee,
          'taxAmount': taxAmount,
          'discountAmount': discountAmount,
          'bookingType': bookingType,
          'paymentMethod': resolvedPaymentMethod,
          'paymentStatus': resolvedPaymentStatus,
          'paymentMode': resolvedPaymentMode,
          'paymentGateway': resolvedPaymentGateway,
          'paymentReference': resolvedPaymentReference,
          'entryCode': entryCode,
          'qrData': qrData,
          'status': bookingStatus,
          'extended': false,
          'reviewed': false,
          'reminderScheduled': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'paymentCapturedAt': paymentCaptured
              ? FieldValue.serverTimestamp()
              : null,
        }, SetOptions(merge: true));

        // ── Update slot status ──────────────────────────────────────────
        tx.update(slotRef, {
          'taken': true,
          'isOccupied': !isUpcomingBooking,
          'isReserved': isUpcomingBooking,
          'status': isUpcomingBooking ? 'reserved' : 'occupied',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // ── Decrement available slots ───────────────────────────────────
        tx.update(parkingRef, {
          'availableSlots': FieldValue.increment(-1),
          'available_slots': FieldValue.increment(-1),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        tx.set(userRef, {
          'activeBookings': FieldValue.increment(1),
        }, SetOptions(merge: true));

        return BookingCreationResult(
          bookingId: bookingRef.id,
          bookingStatus: bookingStatus,
          paymentStatus: resolvedPaymentStatus,
          paymentMethod: resolvedPaymentMethod,
          entryCode: entryCode,
          qrData: qrData,
        );
      });
    } on BookingException {
      rethrow;
    } catch (e) {
      await _audit.logEvent(
        action: 'create_booking_failed',
        reason: e.toString(),
        metadata: {'parkingId': parkingId, 'slotId': slotId},
      );
      rethrow;
    }
  }

  // ─── CREATE (smart parking) ─────────────────────────────────────────────

  Future<SmartParkingBookingResult> createSmartParkingBooking({
    required String parkingId,
    required String parkingName,
    required String parkingAddress,
    required String vehicleNumber,
    String vehicleType = 'Car',
    DateTime? bookingTime,
    String? preferredZoneName,
    int durationHours = 8,
  }) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    final normalizedVehicle = _normalizeVehicleNumber(vehicleNumber);
    if (normalizedVehicle.isEmpty || normalizedVehicle.length < 6) {
      throw BookingException.generic(
        'Invalid vehicle number',
        'Enter a valid vehicle number before booking.',
      );
    }

    final normalizedVehicleType = vehicleType.trim().isEmpty
        ? 'Car'
        : vehicleType.trim();
    final resolvedStart = bookingTime ?? DateTime.now();
    final resolvedDuration = durationHours.clamp(1, 24);
    final resolvedEnd = resolvedStart.add(Duration(hours: resolvedDuration));

    await _guardAgainstSuspiciousActivity(
      userId: user.uid,
      parkingId: parkingId,
      slotId: 'auto',
    );
    await _assertUserHasNoBlockingBooking(user.uid);

    // ── Try Cloud Function first, fallback to client transaction ────────
    try {
      return await _createSmartParkingBookingViaFunction(
        parkingId: parkingId,
        parkingName: parkingName,
        parkingAddress: parkingAddress,
        vehicleNumber: normalizedVehicle,
        vehicleType: normalizedVehicleType,
        bookingTime: resolvedStart,
        preferredZoneName: preferredZoneName,
        durationHours: resolvedDuration,
      );
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackToClientTransaction(error)) {
        throw _mapFunctionsException(error);
      }
    }

    // ── Fallback: client-side transaction ────────────────────────────────
    return _fs.runTransaction<SmartParkingBookingResult>((tx) async {
      final userRef = _fs.collection('users').doc(user.uid);
      final parkingRef = _fs.collection('parking_locations').doc(parkingId);
      final bookingRef = _fs.collection('bookings').doc();
      final auditRef = _fs.collection('booking_audit_log').doc();

      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};
      final activeBookingCount = _intValue(userData['activeBookings']);
      if (activeBookingCount > 0) {
        throw BookingException.generic(
          'Duplicate booking prevented',
          'You already have an active parking booking. Complete it before reserving another slot.',
        );
      }

      final parkingSnap = await tx.get(parkingRef);
      if (!parkingSnap.exists) {
        throw BookingException.generic(
          'Parking unavailable',
          'This parking location is no longer available.',
        );
      }

      final parkingData = parkingSnap.data() ?? <String, dynamic>{};
      if (parkingData['isActive'] == false) {
        throw BookingException.generic(
          'Parking unavailable',
          'This parking location is currently unavailable.',
        );
      }

      final totalSlots = _intValue(
        parkingData['totalSlots'] ?? parkingData['total_slots'],
      );
      final availableSlots = _intValue(
        parkingData['availableSlots'] ?? parkingData['available_slots'],
      );
      if (availableSlots <= 0) {
        throw BookingException.generic(
          'Parking Full',
          'Parking Full. Please try another location or try again later.',
        );
      }

      final zones = _resolveZoneStates(
        parkingData: parkingData,
        totalSlots: totalSlots > 0 ? totalSlots : availableSlots,
      );

      final selectedZone = _pickZone(
        zones: zones,
        preferredZoneName: preferredZoneName,
      );
      if (selectedZone == null) {
        throw BookingException.generic(
          'Parking Full',
          'All zones are currently full. Please retry in a moment.',
        );
      }

      final slotNumber = _findFirstFreeSlot(
        capacity: selectedZone.capacity,
        occupiedNumbers: selectedZone.occupiedSlots,
      );
      if (slotNumber == null) {
        throw BookingException.generic(
          'Parking Full',
          'We could not assign a slot right now. Please retry once.',
        );
      }

      final bookingSequence = _intValue(parkingData['bookingSequence']) + 1;
      final tokenNumber = _buildTokenNumber(bookingSequence);
      final entryCode = _buildEntryCode(bookingRef.id);
      final slotId =
          '${selectedZone.code}-S${slotNumber.toString().padLeft(2, '0')}';
      final qrData = _buildQrData(
        bookingId: bookingRef.id,
        userId: user.uid,
        parkingId: parkingId,
        slotId: slotId,
        slotNumber: slotId,
        entryCode: entryCode,
      );
      final entryInstructions = _buildEntryInstructions(
        zoneName: selectedZone.displayName,
        slotId: slotId,
      );

      // ── Update zone assignments ───────────────────────────────────────
      final updatedAssignments = _copyZoneAssignments(
        parkingData['virtualSlotAssignments'],
      );
      final currentSlots = List<int>.from(
        updatedAssignments[selectedZone.key] ?? const <int>[],
      );
      currentSlots.add(slotNumber);
      currentSlots.sort();
      updatedAssignments[selectedZone.key] = currentSlots;

      final updatedOccupancy = <String, int>{};
      for (final zone in zones) {
        final values = List<int>.from(
          updatedAssignments[zone.key] ?? const <int>[],
        );
        updatedOccupancy[zone.key] = values.length;
      }

      final userName =
          (userData['name'] as String?) ?? user.displayName ?? 'Customer';
      final userEmail = (userData['email'] as String?) ?? user.email ?? '';
      final userPhone = (userData['phone'] as String?) ?? '';

      final bookingPayload = <String, dynamic>{
        'bookingId': bookingRef.id,
        'userId': user.uid,
        'userName': userName,
        'userEmail': userEmail,
        'userPhone': userPhone,
        'parkingId': parkingId,
        'parkingName': parkingName,
        'parkingAddress': parkingAddress,
        'latitude': parkingData['latitude'],
        'longitude': parkingData['longitude'],
        'city': parkingData['city']?.toString() ?? '',
        'vehicle': <String, dynamic>{
          'number': normalizedVehicle,
          'vehicleNumber': normalizedVehicle,
          'type': normalizedVehicleType,
          'vehicleType': normalizedVehicleType,
        },
        'vehicleNumber': normalizedVehicle,
        'vehicleType': normalizedVehicleType,
        'zone': selectedZone.displayName,
        'zoneKey': selectedZone.key,
        'zoneCode': selectedZone.code,
        'zoneIndex': selectedZone.index,
        'slotId': slotId,
        'slotNumber': slotId,
        'zoneSlotNumber': slotNumber,
        'tokenNumber': tokenNumber,
        'status': 'booked',
        'bookingType': 'Smart Parking',
        'amount': 0,
        'amountPaid': 0,
        'totalAmount': 0,
        'paymentMethod': 'No Payment Required',
        'paymentStatus': 'skipped',
        'paymentMode': 'not_required',
        'paymentGateway': 'none',
        'paymentReference': 'NOT_REQUIRED',
        'entryCode': entryCode,
        'qrData': qrData,
        'entryInstructions': entryInstructions,
        'source': 'quick_booking',
        'hours': resolvedDuration,
        'durationMinutes': resolvedDuration * 60,
        'bookingDate': Timestamp.fromDate(
          DateTime(resolvedStart.year, resolvedStart.month, resolvedStart.day),
        ),
        'startTime': Timestamp.fromDate(resolvedStart),
        'endTime': Timestamp.fromDate(resolvedEnd),
        'extended': false,
        'reviewed': false,
        'reminderScheduled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.set(bookingRef, bookingPayload);
      tx.set(auditRef, {
        'bookingId': bookingRef.id,
        'userId': user.uid,
        'parkingId': parkingId,
        'action': 'booking_created',
        'status': 'booked',
        'zone': selectedZone.displayName,
        'slotId': slotId,
        'tokenNumber': tokenNumber,
        'source': 'quick_booking',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(parkingRef, {
        'bookingSequence': bookingSequence,
        'availableSlots': FieldValue.increment(-1),
        'available_slots': FieldValue.increment(-1),
        'virtualSlotAssignments': updatedAssignments,
        'zoneOccupancy': updatedOccupancy,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      tx.set(userRef, {
        'activeBookings': FieldValue.increment(1),
        'currentBookingId': bookingRef.id,
      }, SetOptions(merge: true));

      return SmartParkingBookingResult(
        bookingId: bookingRef.id,
        bookingStatus: 'booked',
        zoneName: selectedZone.displayName,
        slotId: slotId,
        tokenNumber: tokenNumber,
        entryCode: entryCode,
        qrData: qrData,
        entryInstructions: entryInstructions,
        startTime: resolvedStart,
        endTime: resolvedEnd,
      );
    });
  }

  // ─── MARK AS PARKED ─────────────────────────────────────────────────────

  Future<void> markAsParked({required String bookingId}) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    await _fs.runTransaction((tx) async {
      final bookingRef = _fs.collection('bookings').doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw const BookingNotFoundException();

      final data = bookingSnap.data()!;
      if (data['userId'] != user.uid) throw const UnauthorizedException();

      final currentStatus = BookingStatusHelper.normalize(data['status']);
      _validateTransition(currentStatus, 'parked');

      DocumentReference<Map<String, dynamic>>? slotRef;
      final parkingId = data['parkingId']?.toString() ?? '';
      final slotId = data['slotId']?.toString() ?? '';
      if (parkingId.isNotEmpty && slotId.isNotEmpty) {
        final candidate = _fs
            .collection('parking_locations')
            .doc(parkingId)
            .collection('slots')
            .doc(slotId);
        final slotSnap = await tx.get(candidate);
        if (slotSnap.exists) {
          slotRef = candidate;
        }
      }

      tx.update(bookingRef, {
        'status': 'parked',
        'parkedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (slotRef != null) {
        tx.update(slotRef, {
          'taken': true,
          'isReserved': false,
          'isOccupied': true,
          'status': 'occupied',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ─── REQUEST VEHICLE RETRIEVAL ──────────────────────────────────────────

  Future<void> requestVehicleRetrieval({required String bookingId}) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    await _fs.runTransaction((tx) async {
      final bookingRef = _fs.collection('bookings').doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw const BookingNotFoundException();

      final data = bookingSnap.data()!;
      if (data['userId'] != user.uid) throw const UnauthorizedException();

      final currentStatus = BookingStatusHelper.normalize(data['status']);
      _validateTransition(currentStatus, 'requested');

      tx.update(bookingRef, {
        'status': 'requested',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final auditRef = _fs.collection('booking_audit_log').doc();
      tx.set(auditRef, {
        'bookingId': bookingId,
        'userId': user.uid,
        'parkingId': data['parkingId'],
        'action': 'vehicle_requested',
        'status': 'requested',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ─── CANCEL ─────────────────────────────────────────────────────────────

  Future<String> cancelBooking({required String bookingId}) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    // Try Cloud Function first
    try {
      return await _cancelBookingViaFunction(bookingId: bookingId);
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackToClientTransaction(error)) {
        throw _mapFunctionsException(error);
      }
    }

    // Fallback: client-side transaction
    return _fs.runTransaction<String>((tx) async {
      final bookingRef = _fs.collection('bookings').doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw const BookingNotFoundException();

      final data = bookingSnap.data()!;
      if (data['userId'] != user.uid) throw const UnauthorizedException();

      final currentStatus = BookingStatusHelper.normalize(
        data['status'].toString(),
      );
      _validateTransition(currentStatus, 'cancelled');

      final startTs = (data['startTime'] as Timestamp?)?.toDate();
      if (startTs != null) {
        final now = DateTime.now();
        final cutoff = startTs.subtract(const Duration(minutes: 15));

        if (now.isAfter(cutoff) &&
            BookingStatusHelper.isUpcoming(currentStatus)) {
          final minutesLeft = startTs.difference(now).inMinutes;
          throw CancellationNotAllowedException(minutesRemaining: minutesLeft);
        }
      }

      tx.update(bookingRef, {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final releasePlan = await _prepareParkingReleasePlan(tx, data);
      _applyParkingReleasePlan(tx, releasePlan);
      await _decrementUserBookingCounter(tx, data['userId']?.toString());

      return 'Booking cancelled successfully.';
    });
  }

  // ─── EXTEND ─────────────────────────────────────────────────────────────

  Future<DateTime> extendBooking({
    required String bookingId,
    required int extraMinutes,
  }) async {
    final user = _user;
    if (user == null) throw const NotAuthenticatedException();

    return _fs.runTransaction<DateTime>((tx) async {
      final bookingRef = _fs.collection('bookings').doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw const BookingNotFoundException();

      final data = bookingSnap.data()!;
      if (data['userId'] != user.uid) throw const UnauthorizedException();

      final currentStatus = BookingStatusHelper.normalize(
        data['status'].toString(),
      );
      if (!BookingStatusHelper.isLive(currentStatus) &&
          currentStatus != 'active') {
        throw InvalidStatusTransitionException(
          from: currentStatus,
          to: 'extended',
        );
      }

      final endTs = (data['endTime'] as Timestamp).toDate();
      if (DateTime.now().isAfter(endTs)) {
        throw BookingException.generic(
          'Booking expired',
          'This booking has already expired and cannot be extended.',
        );
      }

      final newEnd = endTs.add(Duration(minutes: extraMinutes));
      final parkingId = data['parkingId']?.toString() ?? '';
      final slotId = data['slotId']?.toString() ?? '';

      if (parkingId.isNotEmpty && slotId.isNotEmpty) {
        final overlapping = await _fs
            .collection('bookings')
            .where('parkingId', isEqualTo: parkingId)
            .where('slotId', isEqualTo: slotId)
            .where('status', whereIn: BookingStatusHelper.blockingStatuses)
            .get();

        for (final doc in overlapping.docs) {
          if (doc.id == bookingId) continue;
          final otherStart = (doc.data()['startTime'] as Timestamp).toDate();
          final otherEnd = (doc.data()['endTime'] as Timestamp).toDate();

          if (newEnd.isAfter(otherStart) && endTs.isBefore(otherEnd)) {
            throw SlotAlreadyBookedException(
              conflictStart: otherStart,
              conflictEnd: otherEnd,
            );
          }
        }
      }

      final userBookings = await _fs
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: BookingStatusHelper.blockingStatuses)
          .get();

      for (final doc in userBookings.docs) {
        if (doc.id == bookingId) continue;
        final otherStart = (doc.data()['startTime'] as Timestamp).toDate();
        final otherEnd = (doc.data()['endTime'] as Timestamp).toDate();

        if (newEnd.isAfter(otherStart) && endTs.isBefore(otherEnd)) {
          throw UserBookingOverlapException(existingBookingId: doc.id);
        }
      }

      final startTs = (data['startTime'] as Timestamp).toDate();
      final totalMinutes = newEnd.difference(startTs).inMinutes;
      final hours = (totalMinutes / 60).ceil();

      tx.update(bookingRef, {
        'endTime': Timestamp.fromDate(newEnd),
        'hours': hours,
        'extended': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return newEnd;
    });
  }

  // ─── COMPLETE ───────────────────────────────────────────────────────────

  Future<void> completeBooking({required String bookingId}) async {
    // Try Cloud Function first
    try {
      await _completeBookingViaFunction(bookingId: bookingId);
      return;
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackToClientTransaction(error)) {
        throw _mapFunctionsException(error);
      }
    }

    // Fallback: client-side transaction
    await _fs.runTransaction((tx) async {
      final bookingRef = _fs.collection('bookings').doc(bookingId);
      final bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) throw const BookingNotFoundException();

      final data = bookingSnap.data()!;
      final currentStatus = BookingStatusHelper.normalize(
        data['status'].toString(),
      );
      _validateTransition(currentStatus, 'completed');

      tx.update(bookingRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final releasePlan = await _prepareParkingReleasePlan(tx, data);
      _applyParkingReleasePlan(tx, releasePlan);
      await _decrementUserBookingCounter(tx, data['userId']?.toString());
    });
  }

  // ─── UTILITY ────────────────────────────────────────────────────────────

  bool canCancel(DateTime startTime) {
    return DateTime.now().isBefore(
      startTime.subtract(const Duration(minutes: 15)),
    );
  }

  int minutesUntilCutoff(DateTime startTime) {
    final cutoff = startTime.subtract(const Duration(minutes: 15));
    final diff = cutoff.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  // ─── GUARDS ─────────────────────────────────────────────────────────────

  Future<void> _guardAgainstSuspiciousActivity({
    required String userId,
    required String parkingId,
    required String slotId,
  }) async {
    final suspicious = await _audit.isSuspicious(userId);
    if (!suspicious) return;

    await _audit.logEvent(
      action: 'create_booking_blocked',
      reason: 'suspicious_activity',
      metadata: {'parkingId': parkingId, 'slotId': slotId},
    );
    throw BookingException.generic(
      'Too many failed attempts. Please try again later.',
      'Too many failed attempts. Please wait a few minutes and try again.',
    );
  }

  Future<void> _assertUserHasNoBlockingBooking(String userId) async {
    final snapshot = await _fs
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: BookingStatusHelper.blockingStatuses)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;
    throw BookingException.generic(
      'Duplicate booking prevented',
      'You already have an active parking booking. Complete it before reserving another slot.',
    );
  }

  // ─── PARKING RELEASE ────────────────────────────────────────────────────

  Future<_ParkingReleasePlan?> _prepareParkingReleasePlan(
    Transaction tx,
    Map<String, dynamic> data,
  ) async {
    final parkingId = data['parkingId']?.toString() ?? '';
    if (parkingId.isEmpty) return null;

    final parkingRef = _fs.collection('parking_locations').doc(parkingId);
    DocumentReference<Map<String, dynamic>>? slotRef;
    var releasePhysicalSlot = false;

    final slotId = data['slotId']?.toString() ?? '';
    if (slotId.isNotEmpty) {
      final candidate = parkingRef.collection('slots').doc(slotId);
      final slotSnap = await tx.get(candidate);
      if (slotSnap.exists) {
        slotRef = candidate;
        releasePhysicalSlot = true;
      }
    }

    Map<String, List<int>>? updatedAssignments;
    Map<String, int>? updatedOccupancy;

    final zoneKey = data['zoneKey']?.toString() ?? '';
    final zoneSlotNumber = _intValue(data['zoneSlotNumber']);
    if (zoneKey.isNotEmpty && zoneSlotNumber > 0) {
      final parkingSnap = await tx.get(parkingRef);
      final parkingData = parkingSnap.data() ?? <String, dynamic>{};
      updatedAssignments = _copyZoneAssignments(
        parkingData['virtualSlotAssignments'],
      );
      final updatedZoneValues = List<int>.from(
        updatedAssignments[zoneKey] ?? const <int>[],
      )..remove(zoneSlotNumber);
      updatedAssignments[zoneKey] = updatedZoneValues;

      final occupancy = <String, int>{};
      updatedAssignments.forEach((key, value) {
        occupancy[key] = value.length;
      });
      updatedOccupancy = occupancy;
    }

    return _ParkingReleasePlan(
      parkingRef: parkingRef,
      slotRef: slotRef,
      releasePhysicalSlot: releasePhysicalSlot,
      updatedAssignments: updatedAssignments,
      updatedOccupancy: updatedOccupancy,
    );
  }

  void _applyParkingReleasePlan(
    Transaction tx,
    _ParkingReleasePlan? releasePlan,
  ) {
    if (releasePlan == null) return;

    // Release physical slot if applicable
    if (releasePlan.releasePhysicalSlot && releasePlan.slotRef != null) {
      tx.update(releasePlan.slotRef!, {
        'taken': false,
        'isOccupied': false,
        'isReserved': false,
        'status': 'available',
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    // Update parking document (assignments + increment available)
    if (releasePlan.updatedAssignments != null) {
      tx.update(releasePlan.parkingRef, {
        'virtualSlotAssignments': releasePlan.updatedAssignments,
        'zoneOccupancy': releasePlan.updatedOccupancy,
        'availableSlots': FieldValue.increment(1),
        'available_slots': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      tx.update(releasePlan.parkingRef, {
        'availableSlots': FieldValue.increment(1),
        'available_slots': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _decrementUserBookingCounter(
    Transaction tx,
    String? userId,
  ) async {
    if (userId == null || userId.isEmpty) return;
    final userRef = _fs.collection('users').doc(userId);
    tx.set(userRef, {
      'activeBookings': FieldValue.increment(-1),
      'currentBookingId': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // ─── VALIDATION ─────────────────────────────────────────────────────────

  void _validateTransition(String from, String to) {
    final allowed = _allowedTransitions[from];
    if (allowed == null || !allowed.contains(to)) {
      throw InvalidStatusTransitionException(from: from, to: to);
    }
  }

  bool _slotIsUnavailable(Map<String, dynamic> data) {
    final status = BookingStatusHelper.normalize(data['status']);
    final type = BookingStatusHelper.normalize(data['type']);
    final slotType = BookingStatusHelper.normalize(data['slotType']);

    return data['enabled'] == false ||
        type == 'disabled' ||
        slotType == 'disabled' ||
        data['taken'] == true ||
        data['isOccupied'] == true ||
        data['isReserved'] == true ||
        status == 'reserved' ||
        status == 'occupied' ||
        status == 'active' ||
        status == 'taken' ||
        status == 'live' ||
        status == 'disabled' ||
        status == 'unavailable' ||
        status == 'blocked';
  }

  bool _paymentIsCaptured(String status) {
    final normalized = BookingStatusHelper.normalize(status);
    return normalized == 'paid' ||
        normalized == 'success' ||
        normalized == 'simulated_success' ||
        normalized == 'skipped' ||
        normalized == 'captured';
  }

  // ─── ZONE / SLOT RESOLUTION ─────────────────────────────────────────────

  List<_ZoneState> _resolveZoneStates({
    required Map<String, dynamic> parkingData,
    required int totalSlots,
  }) {
    final rawZones = parkingData['zones'];
    final parsedZones = <Map<String, dynamic>>[];
    if (rawZones is List) {
      for (final zone in rawZones) {
        if (zone is Map) {
          parsedZones.add(zone.map((key, value) => MapEntry('$key', value)));
        }
      }
    }

    if (parsedZones.isEmpty) {
      parsedZones.add(<String, dynamic>{'name': 'General Zone'});
    }

    final zoneCount = parsedZones.length;
    final capacities = <int>[];
    var remaining = totalSlots > 0 ? totalSlots : zoneCount;
    var definedTotal = 0;

    for (final zone in parsedZones) {
      final explicitCapacity = _intValue(
        zone['capacity'] ?? zone['totalSlots'] ?? zone['slots'],
      );
      capacities.add(explicitCapacity);
      definedTotal += explicitCapacity;
    }

    remaining = remaining - definedTotal;
    if (remaining < 0) remaining = 0;

    final evenShare = zoneCount == 0 ? 0 : remaining ~/ zoneCount;
    var remainder = zoneCount == 0 ? 0 : remaining % zoneCount;

    final assignments = _copyZoneAssignments(
      parkingData['virtualSlotAssignments'],
    );

    return List<_ZoneState>.generate(zoneCount, (index) {
      final raw = parsedZones[index];
      final name = raw['name']?.toString().trim().isNotEmpty == true
          ? raw['name'].toString().trim()
          : 'Zone ${index + 1}';
      var capacity = capacities[index];
      if (capacity <= 0) {
        capacity = evenShare + (remainder > 0 ? 1 : 0);
        if (remainder > 0) remainder--;
      }
      if (capacity <= 0) capacity = 1;

      return _ZoneState(
        key: 'zone_${index + 1}',
        displayName: name,
        code: 'Z${index + 1}',
        capacity: capacity,
        index: index,
        occupiedSlots: List<int>.from(
          assignments['zone_${index + 1}'] ?? const <int>[],
        ),
      );
    });
  }

  _ZoneState? _pickZone({
    required List<_ZoneState> zones,
    required String? preferredZoneName,
  }) {
    final preferred = preferredZoneName?.trim().toLowerCase();
    final candidates = zones
        .where((zone) => zone.occupiedSlots.length < zone.capacity)
        .toList();
    if (candidates.isEmpty) return null;

    if (preferred != null && preferred.isNotEmpty) {
      for (final zone in candidates) {
        if (zone.displayName.toLowerCase() == preferred) {
          return zone;
        }
      }
    }

    candidates.sort((a, b) {
      final availableCompare = b.available.compareTo(a.available);
      if (availableCompare != 0) return availableCompare;
      return a.index.compareTo(b.index);
    });
    return candidates.first;
  }

  int? _findFirstFreeSlot({
    required int capacity,
    required List<int> occupiedNumbers,
  }) {
    final occupied = occupiedNumbers.toSet();
    for (var i = 1; i <= capacity; i++) {
      if (!occupied.contains(i)) return i;
    }
    return null;
  }

  // ─── DATA HELPERS ───────────────────────────────────────────────────────

  Map<String, List<int>> _copyZoneAssignments(Object? raw) {
    final result = <String, List<int>>{};
    if (raw is! Map) return result;

    raw.forEach((key, value) {
      final items = <int>[];
      if (value is List) {
        for (final item in value) {
          final parsed = _intValue(item);
          if (parsed > 0) items.add(parsed);
        }
      }
      result['$key'] = items;
    });
    return result;
  }

  int _intValue(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _normalizeVehicleNumber(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').trim();
  }

  String _buildTokenNumber(int bookingSequence) {
    return 'TXP-${bookingSequence.toString().padLeft(4, '0')}';
  }

  String _buildEntryInstructions({
    required String zoneName,
    required String slotId,
  }) {
    return 'Proceed to $zoneName, follow the smart signage, and park at $slotId. Keep your token handy for gate assistance.';
  }

  String _buildEntryCode(String bookingId) {
    final compact = bookingId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (compact.isEmpty) return 'TXP000';
    if (compact.length >= 6) return compact.substring(compact.length - 6);
    return compact.padRight(6, '0');
  }

  String _buildQrData({
    required String bookingId,
    required String userId,
    required String parkingId,
    required String slotId,
    required String slotNumber,
    required String entryCode,
  }) {
    return 'bookingId=$bookingId;userId=$userId;parkingId=$parkingId;slotId=$slotId;slotNumber=$slotNumber;entryCode=$entryCode';
  }

  String _buildPaymentReference({
    required String bookingId,
    required String paymentMethod,
  }) {
    final methodPrefix = paymentMethod
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final compactMethod = methodPrefix.isEmpty
        ? 'PAY'
        : methodPrefix.substring(
            0,
            methodPrefix.length > 4 ? 4 : methodPrefix.length,
          );
    final compactBooking = bookingId
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final bookingSuffix = compactBooking.isEmpty
        ? '0000'
        : compactBooking.substring(
            compactBooking.length > 4 ? compactBooking.length - 4 : 0,
          );
    return '$compactMethod-$bookingSuffix';
  }

  // ─── CLOUD FUNCTIONS ────────────────────────────────────────────────────

  Future<SmartParkingBookingResult> _createSmartParkingBookingViaFunction({
    required String parkingId,
    required String parkingName,
    required String parkingAddress,
    required String vehicleNumber,
    required String vehicleType,
    required DateTime bookingTime,
    required String? preferredZoneName,
    required int durationHours,
  }) async {
    final result = await _functions
        .httpsCallable('createSmartParkingBooking')
        .call({
          'parkingId': parkingId,
          'parkingName': parkingName,
          'parkingAddress': parkingAddress,
          'vehicleNumber': vehicleNumber,
          'vehicleType': vehicleType,
          'bookingTimeMs': bookingTime.millisecondsSinceEpoch,
          'preferredZoneName': preferredZoneName,
          'durationHours': durationHours,
        });

    final data = Map<String, dynamic>.from(result.data as Map);
    return SmartParkingBookingResult(
      bookingId: data['bookingId']?.toString() ?? '',
      bookingStatus: data['bookingStatus']?.toString() ?? 'booked',
      zoneName: data['zoneName']?.toString() ?? 'Zone 1',
      slotId: data['slotId']?.toString() ?? '',
      tokenNumber: data['tokenNumber']?.toString() ?? '',
      entryCode: data['entryCode']?.toString() ?? '',
      qrData: data['qrData']?.toString() ?? '',
      entryInstructions: data['entryInstructions']?.toString() ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(
        _intValue(data['startTimeMs']),
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        _intValue(data['endTimeMs']),
      ),
    );
  }

  Future<String> _cancelBookingViaFunction({required String bookingId}) async {
    final result = await _functions.httpsCallable('cancelParkingBooking').call({
      'bookingId': bookingId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['message']?.toString() ?? 'Booking cancelled successfully.';
  }

  Future<void> _completeBookingViaFunction({required String bookingId}) async {
    await _functions.httpsCallable('completeParkingBooking').call({
      'bookingId': bookingId,
    });
  }

  bool _shouldFallbackToClientTransaction(FirebaseFunctionsException error) {
    return error.code == 'not-found' ||
        error.code == 'unimplemented' ||
        error.code == 'unavailable';
  }

  BookingException _mapFunctionsException(FirebaseFunctionsException error) {
    final userMessage = error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : 'We could not complete this booking action right now.';
    return BookingException.generic(error.code, userMessage);
  }
}

// ─── PRIVATE DATA TYPES ─────────────────────────────────────────────────────

class _ZoneState {
  final String key;
  final String displayName;
  final String code;
  final int capacity;
  final int index;
  final List<int> occupiedSlots;

  const _ZoneState({
    required this.key,
    required this.displayName,
    required this.code,
    required this.capacity,
    required this.index,
    required this.occupiedSlots,
  });

  int get available => capacity - occupiedSlots.length;
}

class _ParkingReleasePlan {
  final DocumentReference<Map<String, dynamic>> parkingRef;
  final DocumentReference<Map<String, dynamic>>? slotRef;
  final bool releasePhysicalSlot;
  final Map<String, List<int>>? updatedAssignments;
  final Map<String, int>? updatedOccupancy;

  const _ParkingReleasePlan({
    required this.parkingRef,
    required this.slotRef,
    required this.releasePhysicalSlot,
    required this.updatedAssignments,
    required this.updatedOccupancy,
  });
}
