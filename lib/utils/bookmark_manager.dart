import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkManager {
  static const String key = "saved_parkings";

  // Save parking
  static Future<void> saveParking(Map<String, dynamic> parking) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> saved = prefs.getStringList(key) ?? [];

    // Convert map to JSON string
    final jsonString = jsonEncode(parking);

    // Avoid duplicates
    if (!saved.contains(jsonString)) {
      saved.add(jsonString);
      await prefs.setStringList(key, saved);
    }
  }

  // Remove parking
  static Future<void> removeParking(String parkingId) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> saved = prefs.getStringList(key) ?? [];

    saved.removeWhere((item) {
      final map = jsonDecode(item);
      return map["id"] == parkingId;
    });

    await prefs.setStringList(key, saved);
  }

  // Get saved list
  static Future<List<Map<String, dynamic>>> getSavedParkings() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> saved = prefs.getStringList(key) ?? [];

    return saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // Check if saved
  static Future<bool> isSaved(String parkingId) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> saved = prefs.getStringList(key) ?? [];

    return saved.any((item) {
      final map = jsonDecode(item);
      return map["id"] == parkingId;
    });
  }
}
