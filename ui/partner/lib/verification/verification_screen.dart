import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VerificationScreen extends StatelessWidget {
  final bool isRejected;
  final String? rejectionReason;

  const VerificationScreen({
    Key? key,
    required this.isRejected,
    this.rejectionReason,
  }) : super(key: key);

  Future<bool> resubmitVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      print('No token found for resubmission');
      return false;
    }

    final response = await http.put(
      Uri.parse('http://192.168.29.86:8000/api/users/partner/profile/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'current_step': 1,
        'is_rejected': false,
        'rejection_reason': '',
      }),
    );

    if (response.statusCode == 200) {
      print('Verification data reset successfully');
      return true;
    } else {
      print('Failed to reset verification: ${response.body}');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  isRejected ? 'Documents Rejected' : 'Verification In-Progress',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRejected
                  ? (rejectionReason ?? 'Document verification failed.')
                  : 'You have successfully completed all verification steps. Your account is now under review.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (isRejected)
                ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      bool success = await resubmitVerification();
                      if (success) {
                        Navigator.pushNamed(context, '/owner-details');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Re-submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
