import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RideState {
  final int? bookingId;
  final String? status;
  final String? driverName;
  final String? vehicleType;
  final String? vehicleNumber;
  final String? driverPhone;
  final String? pickupOtp;
  final String? dropOtp;
  final DateTime? lastUpdated;

  RideState({
    this.bookingId,
    this.status,
    this.driverName,
    this.vehicleType,
    this.vehicleNumber,
    this.driverPhone,
    this.pickupOtp,
    this.dropOtp,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'status': status,
      'driverName': driverName,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'driverPhone': driverPhone,
      'pickupOtp': pickupOtp,
      'dropOtp': dropOtp,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory RideState.fromJson(Map<String, dynamic> json) {
    return RideState(
      bookingId: json['bookingId'],
      status: json['status'],
      driverName: json['driverName'],
      vehicleType: json['vehicleType'],
      vehicleNumber: json['vehicleNumber'],
      driverPhone: json['driverPhone'],
      pickupOtp: json['pickupOtp'],
      dropOtp: json['dropOtp'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : null,
    );
  }

  bool get isActive {
    if (bookingId == null || status == null) return false;
    
    // Check if the ride state is recent (within last 2 hours)
    if (lastUpdated != null) {
      final now = DateTime.now();
      final difference = now.difference(lastUpdated!);
      if (difference.inHours > 2) return false;
    }
    
    // Check if status indicates an active ride
    return ['created', 'arriving', 'in_transit'].contains(status);
  }

  bool get isCompleted {
    return status == 'completed';
  }

  bool get canBeRated {
    return isCompleted && !hasRating;
  }

  bool get hasRating {
    // This would be checked from the backend or local storage
    return false; // Placeholder
  }
}

class RideStateManager {
  static const String _rideStateKey = 'current_ride_state';
  static const String _ratingSubmittedKey = 'rating_submitted_';

  static Future<void> saveRideState(RideState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rideStateKey, jsonEncode(state.toJson()));
  }

  static Future<RideState?> getRideState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_rideStateKey);
    print('Ride state JSON: $stateJson');
    if (stateJson == null) return null;
    
    try {
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      return RideState.fromJson(stateMap);
    } catch (e) {
      print('Error parsing ride state: $e');
      return null;
    }
  }

  static Future<void> clearRideState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rideStateKey);
  }

  static Future<void> updateRideStatus(String status) async {
    final currentState = await getRideState();
    if (currentState != null) {
      final updatedState = RideState(
        bookingId: currentState.bookingId,
        status: status,
        driverName: currentState.driverName,
        vehicleType: currentState.vehicleType,
        vehicleNumber: currentState.vehicleNumber,
        driverPhone: currentState.driverPhone,
        pickupOtp: currentState.pickupOtp,
        dropOtp: currentState.dropOtp,
        lastUpdated: DateTime.now(),
      );
      await saveRideState(updatedState);
    }
  }

  static Future<void> markRatingSubmitted(int bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_ratingSubmittedKey}$bookingId', true);
  }

  static Future<bool> isRatingSubmitted(int bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_ratingSubmittedKey}$bookingId') ?? false;
  }

  static Future<String?> getInitialRoute() async {
    final rideState = await getRideState();
    
    if (rideState == null) {
      return null; // No active ride, go to normal flow
    }

    if (!rideState.isActive) {
      // Clear stale ride state
      await clearRideState();
      return null;
    }

    // Determine which screen to show based on ride status
    switch (rideState.status) {
      case 'created':
      case 'arriving':
      case 'in_transit':
        return '/booking';
      case 'completed':
        if (rideState.canBeRated) {
          return '/rating';
        } else {
          await clearRideState();
          return null;
        }
      default:
        await clearRideState();
        return null;
    }
  }

  static Future<Map<String, dynamic>?> getRatingArguments() async {
    final rideState = await getRideState();
    if (rideState == null || !rideState.canBeRated) return null;

    return {
      'bookingId': rideState.bookingId,
      'driverName': rideState.driverName ?? '',
      'vehicleType': rideState.vehicleType ?? '',
      'vehicleNumber': rideState.vehicleNumber ?? '',
    };
  }

  static Future<int?> getCurrentBookingId() async {
    final rideState = await getRideState();
    return rideState?.bookingId;
  }
} 