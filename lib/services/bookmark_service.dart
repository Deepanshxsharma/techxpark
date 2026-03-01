import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> isSaved(String parkingId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection("users").doc(user.uid).get();
    final List saved = doc.data()?["saved_parkings"] ?? [];

    return saved.contains(parkingId);
  }

  static Future<void> toggleSave(String parkingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore.collection("users").doc(user.uid);
    final snap = await ref.get();
    final List saved = snap.data()?["saved_parkings"] ?? [];

    if (saved.contains(parkingId)) {
      await ref.update({
        "saved_parkings": FieldValue.arrayRemove([parkingId]),
      });
    } else {
      await ref.update({
        "saved_parkings": FieldValue.arrayUnion([parkingId]),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final userDoc =
        await _firestore.collection("users").doc(user.uid).get();

    final List ids = userDoc.data()?["saved_parkings"] ?? [];
    if (ids.isEmpty) return [];

    final List<Map<String, dynamic>> result = [];

    for (final id in ids) {
      final snap =
          await _firestore.collection("parking_locations").doc(id).get();
      if (snap.exists) {
        final data = snap.data()!;
        data["id"] = snap.id;
        result.add(data);
      }
    }
    return result;
  }

  static Future<void> removeBookmark(String parkingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection("users").doc(user.uid).update({
      "saved_parkings": FieldValue.arrayRemove([parkingId]),
    });
  }
}
