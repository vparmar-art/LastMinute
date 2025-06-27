import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'verification_screen.dart';

const String baseUrl = 'http://192.168.0.105:8000/api';

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
      'owner_full_name': ownerFullName,
      'vehicle_type': vehicleType,
      'vehicle_number': vehicleNumber,
      'registration_number': registrationNumber,
      'driver_name': driverFullName,
      'driver_phone': driverPhone,
      'driver_license': driverLicenseNumber,
      'is_agreed_to_terms': isAgreedToTerms,
      'current_step': currentStep,
      'is_rejected': isRejected,
      'rejection_reason': rejectionReason,
    };
  }

  // Method to load data from API
  Future<void> fetchVerificationData(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('Verification API Response: $responseData');
      final data = responseData['properties'];

      ownerFullName = data['owner_full_name'];
      vehicleType = data['vehicle_type'];
      vehicleNumber = data['vehicle_number'];
      registrationNumber = data['registration_number'];
      driverFullName = data['driver_name'];
      driverPhone = data['driver_phone'];
      driverLicenseNumber = data['driver_license'];
      isAgreedToTerms = data['is_agreed_to_terms'] ?? false;
      currentStep = data['current_step'] ?? 1;
      isRejected = data['is_rejected'] ?? false;
      rejectionReason = data['rejection_reason'];
    } else {
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