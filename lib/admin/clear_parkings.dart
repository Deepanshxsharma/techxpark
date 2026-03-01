import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final ref = FirebaseFirestore.instance.collection("parking_locations");
  final docs = await ref.get();

  print("Deleting ${docs.docs.length} parkings...");

  for (var d in docs.docs) {
    await d.reference.delete();
    print("Deleted: ${d.id}");
  }

  print("🧹 DONE — All parkings removed.");
}
