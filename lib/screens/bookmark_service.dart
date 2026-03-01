// lib/services/bookmark_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  static const String key = "bookmarked_parkings";

  // read all
  static Future<List<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  // add
  static Future<void> addBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    if (!list.contains(id)) {
      list.add(id);
      await prefs.setStringList(key, list);
    }
  }

  // remove
  static Future<void> removeBookmark(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    list.remove(id);
    await prefs.setStringList(key, list);
  }

  // check
  static Future<bool> isBookmarked(String id) async {
    final list = await getBookmarks();
    return list.contains(id);
  }
}
