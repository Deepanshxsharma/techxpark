import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final ref = FirebaseFirestore.instance.collection("parking_locations");
  final docs = await ref.get();

  developer.log(
    "Deleting ${docs.docs.length} parkings...",
    name: 'clear_parkings',
  );

  for (var d in docs.docs) {
    await d.reference.delete();
    developer.log("Deleted: ${d.id}", name: 'clear_parkings');
  }

  developer.log("DONE - All parkings removed.", name: 'clear_parkings');
}
