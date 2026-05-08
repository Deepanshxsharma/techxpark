import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../parking_details/lot_detail_navigation.dart';

class SavedLocationsScreen extends StatelessWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Locations',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<Position?>(
        future: _position(),
        builder: (context, positionSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('savedLocations')
                .snapshots(),
            builder: (context, subSnap) {
              if (!subSnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final subDocs = subSnap.data!.docs;
              if (subDocs.isNotEmpty) {
                return _SavedLocationsList(
                  uid: user.uid,
                  position: positionSnap.data,
                  savedRefs: subDocs
                      .map((d) => _SavedRef(id: d.id, data: d.data()))
                      .toList(),
                );
              }
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  final saved =
                      (userSnap.data!.data()?['saved_parkings'] as List? ?? [])
                          .map((e) => e.toString())
                          .toList();
                  if (saved.isEmpty) return _empty(context);
                  return _SavedLocationsList(
                    uid: user.uid,
                    position: positionSnap.data,
                    savedRefs: saved
                        .map((id) => _SavedRef(id: id, data: {'lotId': id}))
                        .toList(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_border_rounded,
              size: 58,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'No saved locations yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore nearby lots and save your favourites for faster bookings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF757686),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedLocationsList extends StatelessWidget {
  final String uid;
  final Position? position;
  final List<_SavedRef> savedRefs;

  const _SavedLocationsList({
    required this.uid,
    required this.position,
    required this.savedRefs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: savedRefs.length,
      itemBuilder: (context, index) {
        final saved = savedRefs[index];
        final lotId =
            saved.data['lotId']?.toString() ??
            saved.data['parkingId']?.toString() ??
            saved.id;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('parking_locations')
              .doc(lotId)
              .get(),
          builder: (context, snap) {
            final lotData = snap.data?.data() ?? saved.data;
            if (snap.connectionState == ConnectionState.done &&
                lotData.isEmpty) {
              return const SizedBox.shrink();
            }
            return _SavedLocationCard(
              uid: uid,
              savedId: saved.id,
              lotId: lotId,
              data: lotData,
              position: position,
            );
          },
        );
      },
    );
  }
}

class _SavedLocationCard extends StatelessWidget {
  final String uid;
  final String savedId;
  final String lotId;
  final Map<String, dynamic> data;
  final Position? position;

  const _SavedLocationCard({
    required this.uid,
    required this.savedId,
    required this.lotId,
    required this.data,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Parking Lot';
    final address = data['address']?.toString() ?? '';
    final image = (data['imageUrl'] ?? data['image'])?.toString() ?? '';
    final distance = _distanceLabel(data, position);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: SizedBox(
                  width: 98,
                  height: 96,
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF757686),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      distance,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.bookmark_remove_rounded,
                  color: Color(0xFFBA1A1A),
                ),
                onPressed: () => _remove(context),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF1F4F9)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () =>
                    openLotDetail(context, lotId, {...data, 'id': lotId}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Book Now',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFEEF2FF),
    child: const Icon(
      Icons.local_parking_rounded,
      color: AppColors.primary,
      size: 34,
    ),
  );

  String _distanceLabel(Map<String, dynamic> data, Position? position) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || position == null) {
      return 'Distance unavailable';
    }
    final meters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      lat,
      lng,
    );
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km away';
    return '${meters.round()} m away';
  }

  Future<void> _remove(BuildContext context) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef
        .collection('savedLocations')
        .doc(savedId)
        .delete()
        .catchError((_) {});
    await userRef.set({
      'saved_parkings': FieldValue.arrayRemove([lotId]),
    }, SetOptions(merge: true));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SavedRef {
  final String id;
  final Map<String, dynamic> data;

  const _SavedRef({required this.id, required this.data});
}

Future<Position?> _position() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition();
  } catch (_) {
    return null;
  }
}
