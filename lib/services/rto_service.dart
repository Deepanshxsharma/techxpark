import 'package:cloud_functions/cloud_functions.dart';

class RTOService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static Future<Map<String, dynamic>?> fetchVehicleInfo(
    String vehicleNumber,
  ) async {
    final normalized = vehicleNumber
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .trim();
    if (normalized.length < 6) return null;

    try {
      final response = await _functions
          .httpsCallable('verifyVehicleInfo')
          .call({'vehicleNumber': normalized})
          .timeout(const Duration(seconds: 15));
      final data = response.data;
      if (data is Map && data['result'] is Map) {
        return Map<String, dynamic>.from(data['result'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
