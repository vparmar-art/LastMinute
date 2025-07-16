import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';
import '../utils/ride_state_manager.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  int? pickupBookingId;
  double? pickupLatitude;
  double? pickupLongitude;
  String? pickupAddress;
  String? pickupOtp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && pickupLatitude == null && pickupLongitude == null && pickupAddress == null) {
        setState(() {
          pickupBookingId = args['id'];
          pickupLatitude = args['pickup_lat'];
          pickupLongitude = args['pickup_lng'];
          pickupAddress = args['pickup_address'];
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    
    int? bookingId = args?['id'];
    String? pickupAddress = args?['pickup_address'];
    String? pickupOtp = args?['pickup_otp'];
    double? pickupLat = args?['pickup_lat'];
    double? pickupLng = args?['pickup_lng'];
    
    // Set lat/lng from arguments if provided
    if (pickupLat != null && pickupLng != null) {
      setState(() {
        pickupLatitude = pickupLat;
        pickupLongitude = pickupLng;
      });
    }
    
    _restoreRideState(bookingId, pickupAddress, pickupOtp);
  }

  Future<void> _restoreRideState(int? bookingId, String? pickupAddress, String? pickupOtp) async {
    final rideState = await PartnerRideStateManager.getRideState();
    
    if (rideState != null && rideState.isActive && (bookingId == null || rideState.bookingId == bookingId)) {
      setState(() {
        // Use arguments if present, else fallback to ride state
        this.pickupBookingId = rideState.bookingId;
        this.pickupAddress = pickupAddress ?? rideState.pickupLocation;
        this.pickupOtp = pickupOtp ?? rideState.pickupOtp;
        // Restore lat/lng from ride state if not already set
        if (pickupLatitude == null && rideState.pickupLat != null) {
          pickupLatitude = rideState.pickupLat;
        }
        if (pickupLongitude == null && rideState.pickupLng != null) {
          pickupLongitude = rideState.pickupLng;
        }
      });
    }
  }

  Future<void> _persistRideState(String status) async {
    // Use booking details from your state
    final rideState = PartnerRideState(
      bookingId: pickupBookingId!,
      status: status,
      // Add other fields as needed
      lastUpdated: DateTime.now(),
    );
    await PartnerRideStateManager.saveRideState(rideState);
  }

  Future<void> _persistRideStateInTransit({
    required int bookingId,
    required String? dropAddress,
    required String? dropOtp,
    required double? dropLat,
    required double? dropLng,
  }) async {
    
    final rideState = PartnerRideState(
      bookingId: bookingId,
      status: 'in_transit',
      dropLocation: dropAddress,
      dropOtp: dropOtp,
      dropLat: dropLat,
      dropLng: dropLng,
      lastUpdated: DateTime.now(),
    );
    await PartnerRideStateManager.saveRideState(rideState);
  }

  void _launchNavigation() async {
    if (pickupLatitude != null && pickupLongitude != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$pickupLatitude,$pickupLongitude');
      try {
        await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    }
  }

  void _checkIfArrived() async {
    if (pickupLatitude == null || pickupLongitude == null) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      pickupLatitude!,
      pickupLongitude!,
    );

    if (distance < 150) {
      _showOtpDialog();
      // Call an API here if needed
    }
  }

  void _showOtpDialog() {
    String enteredOtp = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter 4-digit OTP'),
          content: TextField(
            maxLength: 4,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              enteredOtp = value;
            },
            decoration: const InputDecoration(
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (enteredOtp.length != 4 || pickupBookingId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid OTP or Booking ID')),
                  );
                  return;
                }

                try {
                  final response = await http.post(
                    Uri.parse('$apiBaseUrl/bookings/validate-pickup-otp/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'booking_id': pickupBookingId,
                      'otp': enteredOtp,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final responseData = jsonDecode(response.body);
                    
                    // Extract drop details
                    final dropAddress = responseData['drop_location'];
                    final dropOtp = responseData['drop_otp'];
                    final dropLatLng = responseData['drop_latlng'];
                    final dropLat = dropLatLng?['lat'] ?? dropLatLng?['coordinates']?[1];
                    final dropLng = dropLatLng?['lng'] ?? dropLatLng?['coordinates']?[0];
                    
                    // Persist all drop details in ride state
                    await _persistRideStateInTransit(
                      bookingId: pickupBookingId!,
                      dropAddress: dropAddress,
                      dropOtp: dropOtp,
                      dropLat: dropLat,
                      dropLng: dropLng,
                    );
                    Navigator.pushNamed(
                      context,
                      '/drop',
                      arguments: {
                        'booking_id': pickupBookingId,
                        'drop_location': responseData['drop_location'],
                        'drop_latlng': responseData['drop_latlng'],
                        'drop_otp': responseData['drop_otp'],
                      },
                    );
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ Invalid OTP. Please try again.')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Error validating OTP')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pickup Verification',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.grey.shade100,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Booking ID: ${pickupBookingId ?? "-"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Pickup Coordinates: (${pickupLatitude ?? "-"}, ${pickupLongitude ?? "-"})',
            ),
            const SizedBox(height: 10),
            if (pickupAddress != null)
              Text(
                'Pickup Address: $pickupAddress',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _launchNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _checkIfArrived,
              icon: const Icon(Icons.location_on),
              label: const Text('Mark as Arrived'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}