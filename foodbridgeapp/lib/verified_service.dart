import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VerifiedService {
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await _storage.read(key: 'token');
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('https://foodbridge1.onrender.com/me'),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }
}