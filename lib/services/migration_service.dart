import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Production-ready migration service with 4 phases:
/// 1. MIGRATE — Copy old data to new structure
/// 2. VERIFY — Compare slot counts, ensure floor fields exist
/// 3. CLEAN — Remove duplicate booking fields (snake_case → camelCase)
/// 4. DELETE — Safely remove old collections
///
/// Idempotent: safe to run multiple times.
class MigrationService {
  static final _fs = FirebaseFirestore.instance;

  static Future<void> runMigration() async {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚀 FIRESTORE MIGRATION SERVICE — STARTING');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      await _phase1Migrate();
      final verified = await _phase2Verify();
      await _phase3CleanBookings();

      if (verified) {
        await _phase4DeleteOldCollections();
      } else {
        debugPrint('⚠️ SKIPPING DELETION — verification found mismatches.');
        debugPrint('⚠️ Please check the logs above and run again.');
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🎉 MIGRATION SERVICE COMPLETE');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      debugPrint('❌ CRITICAL MIGRATION ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PHASE 1: MIGRATE — Copy old → new
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _phase1Migrate() async {
    debugPrint('\n📦 PHASE 1: MIGRATE');
    debugPrint('─────────────────────────────────────────');

    // ── 1a. Copy locations → parking_locations ──
    final locSnap = await _fs.collection('locations').get();
    int locCopied = 0;

    for (final doc in locSnap.docs) {
      final target = _fs.collection('parking_locations').doc(doc.id);
      final existing = await target.get();

      if (!existing.exists) {
        final data = Map<String, dynamic>.from(doc.data());

        // Standardize rating fields
        if (data.containsKey('averageRating')) {
          data['ratingAverage'] = data.remove('averageRating');
        }
        if (data.containsKey('totalReviews')) {
          data['ratingCount'] = data.remove('totalReviews');
        }
        data.putIfAbsent('ratingAverage', () => 0.0);
        data.putIfAbsent('ratingCount', () => 0);
        data.putIfAbsent('imageUrl', () =>
            'https://images.unsplash.com/photo-1590674899484-d5640e854abe?q=80&w=800');
        data.putIfAbsent('isActive', () => true);
        data.putIfAbsent('lastUpdated', () => FieldValue.serverTimestamp());

        await target.set(data);
        locCopied++;
        debugPrint('  ✅ Copied location: ${doc.id}');
      }

      // ── Flatten floors → slots ──
      final floorsSnap = await doc.reference.collection('floors').get();
      for (final floorDoc in floorsSnap.docs) {
        final floorNum =
            int.tryParse(floorDoc.id.replaceAll('floor_', '')) ?? 1;
        final floorIndex = floorNum - 1;

        final slotsSnap =
            await floorDoc.reference.collection('slots').get();
        for (final slotDoc in slotsSnap.docs) {
          // Only copy if not already in new structure
          final newSlotRef =
              target.collection('slots').doc(slotDoc.id);
          final newSlotSnap = await newSlotRef.get();

          if (!newSlotSnap.exists) {
            final slotData = Map<String, dynamic>.from(slotDoc.data());
            slotData['floor'] = floorIndex;
            slotData.putIfAbsent('type', () => 'car');
            slotData.putIfAbsent('isActive', () => true);
            slotData.putIfAbsent('isOccupied', () => slotData['taken'] ?? false);
            slotData.putIfAbsent('slotNumber', () => slotDoc.id);

            await newSlotRef.set(slotData);
          } else {
            // Ensure floor field exists even on existing slots
            final existingData = newSlotSnap.data() ?? {};
            if (!existingData.containsKey('floor')) {
              await newSlotRef.update({'floor': floorIndex});
            }
          }
        }
        debugPrint(
            '    📂 Processed ${slotsSnap.docs.length} slots from ${floorDoc.id} → parking_locations/${doc.id}/slots');
      }

      // ── Move reviews to top-level ──
      final reviewsSnap = await doc.reference.collection('reviews').get();
      for (final rev in reviewsSnap.docs) {
        final existingRev =
            await _fs.collection('reviews').doc(rev.id).get();
        if (!existingRev.exists) {
          final revData = Map<String, dynamic>.from(rev.data());
          revData['parkingId'] = doc.id;
          await _fs.collection('reviews').doc(rev.id).set(revData);
        }
      }
      if (reviewsSnap.docs.isNotEmpty) {
        debugPrint(
            '    ⭐ Moved ${reviewsSnap.docs.length} reviews to top-level');
      }
    }

    // ── 1b. Copy parkings → parking_locations ──
    final parkSnap = await _fs.collection('parkings').get();
    int parkCopied = 0;
    for (final doc in parkSnap.docs) {
      final target = _fs.collection('parking_locations').doc(doc.id);
      final existing = await target.get();
      if (!existing.exists) {
        final data = Map<String, dynamic>.from(doc.data());
        data.putIfAbsent('ratingAverage', () => 0.0);
        data.putIfAbsent('ratingCount', () => 0);
        data.putIfAbsent('isActive', () => true);
        await target.set(data);
        parkCopied++;
      }
    }

    // ── 1c. Move user notifications to top-level ──
    final usersSnap = await _fs.collection('users').get();
    int notifsMoved = 0;
    for (final userDoc in usersSnap.docs) {
      final notifsSnap =
          await userDoc.reference.collection('notifications').get();
      for (final notif in notifsSnap.docs) {
        final existing =
            await _fs.collection('notifications').doc(notif.id).get();
        if (!existing.exists) {
          final nData = Map<String, dynamic>.from(notif.data());
          nData['userId'] = userDoc.id;
          if (nData.containsKey('created_at') &&
              !nData.containsKey('createdAt')) {
            nData['createdAt'] = nData.remove('created_at');
          }
          await _fs.collection('notifications').doc(notif.id).set(nData);
          notifsMoved++;
        }
      }

      // Add role, isVerified, and booking quota fields if missing
      final userData = userDoc.data();
      final updates = <String, dynamic>{};
      if (!userData.containsKey('role')) updates['role'] = 'user';
      if (!userData.containsKey('isVerified')) updates['isVerified'] = true;
      if (!userData.containsKey('activeBookings')) updates['activeBookings'] = 0;
      if (!userData.containsKey('maxActiveBookings')) updates['maxActiveBookings'] = 3;
      if (updates.isNotEmpty) await userDoc.reference.update(updates);
    }

    // ── 1d. Standardize gate_requests ──
    final gateSnap = await _fs.collection('gate_requests').get();
    int gateFixed = 0;
    for (final doc in gateSnap.docs) {
      final data = doc.data();
      if (data.containsKey('user_id') && !data.containsKey('userId')) {
        await doc.reference.update({
          'userId': data['user_id'],
          'user_id': FieldValue.delete(),
        });
        gateFixed++;
      }
    }

    debugPrint('  📊 Phase 1 Summary:');
    debugPrint('     Locations copied: $locCopied');
    debugPrint('     Parkings copied: $parkCopied');
    debugPrint('     Notifications moved: $notifsMoved');
    debugPrint('     Gate requests fixed: $gateFixed');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PHASE 2: VERIFY — Compare old vs new slot counts
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<bool> _phase2Verify() async {
    debugPrint('\n🔍 PHASE 2: VERIFY');
    debugPrint('─────────────────────────────────────────');

    bool allGood = true;

    final locSnap = await _fs.collection('locations').get();

    for (final doc in locSnap.docs) {
      // Count old slots across all floors
      int oldSlotCount = 0;
      final floorsSnap = await doc.reference.collection('floors').get();
      for (final floorDoc in floorsSnap.docs) {
        final slotsSnap =
            await floorDoc.reference.collection('slots').get();
        oldSlotCount += slotsSnap.docs.length;
      }

      // Count new slots
      final newSlotsSnap = await _fs
          .collection('parking_locations')
          .doc(doc.id)
          .collection('slots')
          .get();
      final newSlotCount = newSlotsSnap.docs.length;

      // Verify floor field exists on every new slot
      int missingFloor = 0;
      for (final slot in newSlotsSnap.docs) {
        final data = slot.data();
        if (!data.containsKey('floor')) {
          missingFloor++;
        }
      }

      final match = oldSlotCount == newSlotCount;
      final icon = match ? '✅' : '❌';

      debugPrint(
          '  $icon ${doc.id}: old=$oldSlotCount  new=$newSlotCount  missingFloor=$missingFloor');

      if (!match) allGood = false;
      if (missingFloor > 0) {
        debugPrint('     ⚠️ $missingFloor slots missing floor field!');
        allGood = false;
      }
    }

    // Verify parking_locations document count
    final newLocSnap = await _fs.collection('parking_locations').get();
    final parkSnap = await _fs.collection('parkings').get();
    final expectedCount = <String>{
      ...locSnap.docs.map((d) => d.id),
      ...parkSnap.docs.map((d) => d.id),
    }.length;

    debugPrint(
        '  📊 parking_locations: ${newLocSnap.docs.length} (expected ≥ $expectedCount)');

    if (newLocSnap.docs.length < expectedCount) allGood = false;

    // ── Compute totalSlots and availableSlots for heatmap ──
    debugPrint('  🔢 Computing slot counts for heatmap...');
    for (final parkDoc in newLocSnap.docs) {
      final parkData = parkDoc.data() as Map<String, dynamic>;
      if (!parkData.containsKey('totalSlots') || !parkData.containsKey('availableSlots')) {
        final slotsSnap = await parkDoc.reference.collection('slots').get();
        final total = slotsSnap.docs.length;

        // Count active bookings for this parking
        final activeBookingsSnap = await _fs
            .collection('bookings')
            .where('parkingId', isEqualTo: parkDoc.id)
            .where('status', whereIn: ['upcoming', 'active'])
            .get();
        final occupied = activeBookingsSnap.docs.length;
        final available = (total - occupied).clamp(0, total);

        await parkDoc.reference.update({
          'totalSlots': total,
          'availableSlots': available,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        debugPrint('    ✅ ${parkDoc.id}: total=$total available=$available');
      }
    }

    debugPrint(allGood
        ? '  ✅ ALL VERIFICATIONS PASSED'
        : '  ❌ SOME VERIFICATIONS FAILED — see above');

    return allGood;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PHASE 3: CLEAN BOOKING FIELDS (snake_case → camelCase only)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _phase3CleanBookings() async {
    debugPrint('\n🧹 PHASE 3: CLEAN BOOKINGS');
    debugPrint('─────────────────────────────────────────');

    final bookSnap = await _fs.collection('bookings').get();
    int cleaned = 0;

    for (final doc in bookSnap.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      // ── Rename snake_case → camelCase ──
      if (data.containsKey('user_id')) {
        if (!data.containsKey('userId')) {
          updates['userId'] = data['user_id'];
        }
        updates['user_id'] = FieldValue.delete();
      }

      if (data.containsKey('parking_id')) {
        if (!data.containsKey('parkingId')) {
          updates['parkingId'] = data['parking_id'];
        }
        updates['parking_id'] = FieldValue.delete();
      }

      if (data.containsKey('parking_name')) {
        if (!data.containsKey('parkingName')) {
          updates['parkingName'] = data['parking_name'];
        }
        updates['parking_name'] = FieldValue.delete();
      }

      if (data.containsKey('slot_id')) {
        if (!data.containsKey('slotId')) {
          updates['slotId'] = data['slot_id'];
        }
        updates['slot_id'] = FieldValue.delete();
      }

      if (data.containsKey('start_ts')) {
        if (!data.containsKey('startTime')) {
          updates['startTime'] = data['start_ts'];
        }
        updates['start_ts'] = FieldValue.delete();
      }

      if (data.containsKey('end_ts')) {
        if (!data.containsKey('endTime')) {
          updates['endTime'] = data['end_ts'];
        }
        updates['end_ts'] = FieldValue.delete();
      }

      if (data.containsKey('created_at')) {
        if (!data.containsKey('createdAt')) {
          updates['createdAt'] = data['created_at'];
        }
        updates['created_at'] = FieldValue.delete();
      }

      if (data.containsKey('total_price')) {
        if (!data.containsKey('totalPrice')) {
          updates['totalPrice'] = data['total_price'];
        }
        updates['total_price'] = FieldValue.delete();
      }

      if (data.containsKey('price_per_hour')) {
        updates['price_per_hour'] = FieldValue.delete();
      }

      // ── Add missing boolean fields ──
      if (!data.containsKey('extended')) updates['extended'] = false;
      if (!data.containsKey('reviewed')) updates['reviewed'] = false;
      if (!data.containsKey('reminderScheduled')) {
        updates['reminderScheduled'] = false;
      }

      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
        cleaned++;
      }
    }

    debugPrint('  ✅ Cleaned $cleaned / ${bookSnap.docs.length} bookings');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PHASE 4: DELETE OLD COLLECTIONS (only if Phase 2 passed)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> _phase4DeleteOldCollections() async {
    debugPrint('\n🗑️ PHASE 4: DELETE OLD COLLECTIONS');
    debugPrint('─────────────────────────────────────────');

    // ── Delete locations/{id}/floors/{fId}/slots/{sId} (deepest first) ──
    final locSnap = await _fs.collection('locations').get();
    for (final doc in locSnap.docs) {
      final floorsSnap = await doc.reference.collection('floors').get();
      for (final floorDoc in floorsSnap.docs) {
        // Delete all slots in this floor
        final slotsSnap =
            await floorDoc.reference.collection('slots').get();
        for (final slotDoc in slotsSnap.docs) {
          await slotDoc.reference.delete();
        }
        // Delete floor document
        await floorDoc.reference.delete();
      }

      // Delete reviews subcollection
      final reviewsSnap = await doc.reference.collection('reviews').get();
      for (final rev in reviewsSnap.docs) {
        await rev.reference.delete();
      }

      // Delete location document itself
      await doc.reference.delete();
      debugPrint('  🗑️ Deleted old location: ${doc.id}');
    }

    // ── Delete old parkings collection ──
    final parkSnap = await _fs.collection('parkings').get();
    for (final doc in parkSnap.docs) {
      await doc.reference.delete();
    }
    if (parkSnap.docs.isNotEmpty) {
      debugPrint(
          '  🗑️ Deleted ${parkSnap.docs.length} old parking documents');
    }

    // ── Delete old user notification subcollections ──
    final usersSnap = await _fs.collection('users').get();
    int oldNotifsDeleted = 0;
    for (final userDoc in usersSnap.docs) {
      final notifsSnap =
          await userDoc.reference.collection('notifications').get();
      for (final notif in notifsSnap.docs) {
        await notif.reference.delete();
        oldNotifsDeleted++;
      }
    }
    if (oldNotifsDeleted > 0) {
      debugPrint(
          '  🗑️ Deleted $oldNotifsDeleted old user notification subcollection docs');
    }

    debugPrint('  ✅ Old collections deleted successfully');
  }
}
