import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PartnerRideState {
  final int? bookingId;
  final String? status;
  final String? customerName;
  final String? pickupLocation;
  final String? dropLocation;
  final String? pickupOtp;
  final String? dropOtp;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final DateTime? lastUpdated;

  PartnerRideState({
    this.bookingId,
    this.status,
    this.customerName,
    this.pickupLocation,
    this.dropLocation,
    this.pickupOtp,
    this.dropOtp,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'status': status,
      'customerName': customerName,
      'pickupLocation': pickupLocation,
      'dropLocation': dropLocation,
      'pickupOtp': pickupOtp,
      'dropOtp': dropOtp,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory PartnerRideState.fromJson(Map<String, dynamic> json) {
    return PartnerRideState(
      bookingId: json['bookingId'],
      status: json['status'],
      customerName: json['customerName'],
      pickupLocation: json['pickupLocation'],
      dropLocation: json['dropLocation'],
      pickupOtp: json['pickupOtp'],
      dropOtp: json['dropOtp'],
      pickupLat: json['pickupLat'],
      pickupLng: json['pickupLng'],
      dropLat: json['dropLat'],
      dropLng: json['dropLng'],
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

  bool get needsPickupValidation {
    return status == 'arriving';
  }

  bool get needsDropValidation {
    return status == 'in_transit';
  }
}

class PartnerRideStateManager {
  static const String _rideStateKey = 'current_partner_ride_state';

  static Future<void> saveRideState(PartnerRideState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rideStateKey, jsonEncode(state.toJson()));
  }

  static Future<PartnerRideState?> getRideState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString(_rideStateKey);
    if (stateJson == null) return null;
    
    try {
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      return PartnerRideState.fromJson(stateMap);
    } catch (e) {
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
      final updatedState = PartnerRideState(
        bookingId: currentState.bookingId,
        status: status,
        customerName: currentState.customerName,
        pickupLocation: currentState.pickupLocation,
        dropLocation: currentState.dropLocation,
        pickupOtp: currentState.pickupOtp,
        dropOtp: currentState.dropOtp,
        lastUpdated: DateTime.now(),
      );
      await saveRideState(updatedState);
    }
  }

  static Future<Map<String, dynamic>?> getInitialRouteWithArgs() async {
    final rideState = await getRideState();
    
    if (rideState == null || !rideState.isActive) {
      await clearRideState();
      return null;
    }
    
    switch (rideState.status) {
      case 'created':
        return {
          'route': '/booking-detail',
          'arguments': {'id': rideState.bookingId}
        };
      case 'arriving':
        return {
          'route': '/pick-up',
          'arguments': {
            'id': rideState.bookingId,
            'pickup_address': rideState.pickupLocation,
            'pickup_otp': rideState.pickupOtp,
            'pickup_lat': rideState.pickupLat,
            'pickup_lng': rideState.pickupLng,
          }
        };
      case 'in_transit':
        return {
          'route': '/drop',
          'arguments': {
            'id': rideState.bookingId,
            'drop_address': rideState.dropLocation,
            'drop_otp': rideState.dropOtp,
            'drop_lat': rideState.dropLat,
            'drop_lng': rideState.dropLng,
          }
        };
      case 'completed':
        await clearRideState();
        return null;
      default:
        await clearRideState();
        return null;
    }
  }

  static Future<Map<String, dynamic>?> getBookingArguments() async {
    final rideState = await getRideState();
    if (rideState == null) return null;

    return {
      'id': rideState.bookingId,
    };
  }
} 