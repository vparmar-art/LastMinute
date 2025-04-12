import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.29.86:8000/api/users';

  Future<String> sayHello() async {
    final response = await http.get(Uri.parse('$baseUrl/hello/'));
    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load greeting');
    }
  }

  Future<bool> sendOtp(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/send-otp');
    final response = await http.post(
      url,
      body: {'phone_number': phoneNumber},
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to send OTP');
    }
  }

  Future<String> verifyOtp(String phoneNumber, String otp) async {
    final url = Uri.parse('$baseUrl/verify-otp');
    final response = await http.post(
      url,
      body: {
        'phone_number': phoneNumber,
        'otp': otp,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token'];
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'OTP verification failed');
    }
  }
}