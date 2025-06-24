import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';

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
        print('📦 PickupScreen args: id=$pickupBookingId, pickupLatitude=$pickupLatitude, pickupLongitude=$pickupLongitude, pickupAddress=$pickupAddress');
      }
    });
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
      print('❌ Cannot check arrival: pickupLatitude or pickupLongitude is null');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print('⚠️ Location permission is denied');
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

    print('📍 Distance to pickup: $distance meters');

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

                // Only close the dialog after successful verification

                print('✅ OTP entered: $enteredOtp');
                try {
                  final response = await http.post(
                    Uri.parse('http://192.168.0.101:8000/api/bookings/validate-pickup-otp/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'booking_id': pickupBookingId,
                      'otp': enteredOtp,
                    }),
                  );

                  if (response.statusCode == 200) {
                    print('🔁 OTP Validation Response: ${response.statusCode}');
                    print('🔁 Response Body: ${response.body}');
                    final responseData = jsonDecode(response.body);
                    Navigator.pushNamed(
                      context,
                      '/drop',
                      arguments: {
                        'booking_id': pickupBookingId,
                        'drop_location': responseData['drop_location'],
                        'drop_latlng': responseData['drop_latlng'],
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
                  print('Error: $e');
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