import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "https://whole-taxes-rule.loca.lt/api"; // IP mágica para hablar con Docker desde Android
  String? _token;

  void setToken(String token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendLocation(double lat, double lon, double speed, double accuracy, String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/location/ping"),
        headers: _headers,
        body: jsonEncode({
          'latitude': lat,
          'longitude': lon,
          'speed': speed,
          'accuracy': accuracy,
          'deviceId': deviceId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      // Guardar localmente si falla
      return false;
    }
  }

  Future<List<dynamic>> getGeofences() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/geofence"),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getGlobalLocations() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/location/all"),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
