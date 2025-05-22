import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verification_screen.dart';

class VerificationData {
  // Step 1 - Vehicle Owner Info
  String? ownerFullName;
  String? vehicleType;
  String? vehicleNumber;
  String? registrationNumber;

  // Step 2 - Driver Info
  String? driverFullName;
  String? driverPhone;
  String? driverLicenseNumber;

  // Step 3 - Verification step could have documents, selfie, etc.
  bool isAgreedToTerms = false;
  int currentStep = 1;

  bool isRejected = false;
  String? rejectionReason;

  Map<String, dynamic> toJson() {
    return {
      'ownerFullName': ownerFullName,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'registrationNumber': registrationNumber,
      'driverFullName': driverFullName,
      'driverPhone': driverPhone,
      'driverLicenseNumber': driverLicenseNumber,
      'isAgreedToTerms': isAgreedToTerms,
      'currentStep': currentStep,  // Add current step to the JSON data
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
    };
  }

  // Method to load data from API
  Future<void> fetchVerificationData(String token) async {
    final response = await http.get(
      Uri.parse('http://192.168.0.101:8000/api/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Verification API Response: $data');  // Print response to console

      ownerFullName = data['owner_full_name'];
      vehicleType = data['vehicle_type'];
      vehicleNumber = data['vehicle_number'];
      registrationNumber = data['registration_number'];
      driverFullName = data['driver_full_name'];
      driverPhone = data['driver_phone'];
      driverLicenseNumber = data['driver_license_number'];
      isAgreedToTerms = data['is_agreed_to_terms'] ?? false;  // Corrected key name and default
      currentStep = data['current_step'] ?? 1;  // Default to step 1 if null
      isRejected = data['is_rejected'] ?? false;
      rejectionReason = data['rejection_reason'];
    } else {
      // Handle API error response here
      throw Exception('Failed to load verification data');
    }
  }
}

class VerificationController {
  static final VerificationController _instance = VerificationController._internal();

  factory VerificationController() {
    return _instance;
  }

  VerificationController._internal();

  final VerificationData data = VerificationData();

  // Add this method to handle navigation based on current step
  void handleCurrentStep(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      print('No token found');
      return;
    }
    
    try {
      await loadVerificationData(token);
      if (data.currentStep == 1) {
        Navigator.pushNamed(context, '/owner-details');
      } else if (data.currentStep == 2) {
        Navigator.pushNamed(context, '/driver-details');
      } else if (data.currentStep == 3) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(
              isRejected: data.isRejected,
              rejectionReason: data.rejectionReason,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error loading verification data: $e');
    }
  }

  Future<void> loadVerificationData(String token) async {
    await data.fetchVerificationData(token);
  }

  void reset() {
    data.ownerFullName = null;
    data.vehicleType = null;
    data.vehicleNumber = null;
    data.registrationNumber = null;
    data.driverFullName = null;
    data.driverPhone = null;
    data.driverLicenseNumber = null;
    data.isAgreedToTerms = false;
    data.currentStep = 1;  // Reset current step
  }
}