import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';

class RTOService {
  static Future<Map<String, dynamic>?> fetchVehicleInfo(String vehicleNumber) async {
    final url = Uri.parse(
      "https://rto-vehicle-information-verification-india.p.rapidapi.com/api/v1/vehicle_info",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-RapidAPI-Key": ApiKeys.rapidApiKey,
          "X-RapidAPI-Host": ApiKeys.rapidApiHost,
        },
        body: jsonEncode({
          "reg_no": vehicleNumber,
          "consent": "Y",
          "consent_text": "I hereby declare my consent"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["result"];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
