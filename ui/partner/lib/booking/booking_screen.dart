import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int? bookingId;
  double? pickupLat;
  double? pickupLng;
  String? pickupAddress;
  String? _dropLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          bookingId = args['id'];
          pickupLat = args['pickup_lat'];
          pickupLng = args['pickup_lng'];
          pickupAddress = args['pickup_address'];
        });
        print('📦 BookingScreen args: id=$bookingId, pickupLat=$pickupLat, pickupLng=$pickupLng, pickupAddress=$pickupAddress');
      }
    });
  }

  void _launchNavigation() async {
    if (pickupLat != null && pickupLng != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$pickupLat,$pickupLng');
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
    if (pickupLat == null || pickupLng == null) {
      print('❌ Cannot check arrival: pickupLat or pickupLng is null');
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
      pickupLat!,
      pickupLng!,
    );

    print('📍 Distance to pickup: $distance meters');

    if (distance < 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ You have arrived at the pickup location')),
      );
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
                if (enteredOtp.length != 4 || bookingId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid OTP or Booking ID')),
                  );
                  return;
                }

                ; // Close the dialog immediately

                print('✅ OTP entered: $enteredOtp');
                try {
                  final response = await http.post(
                    Uri.parse('http://192.168.0.101:8000/api/bookings/validate-pickup-otp/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'booking_id': bookingId,
                      'otp': enteredOtp,
                    }),
                  );

                  if (response.statusCode == 200) {
                    Navigator.of(context).pop();
                    final data = jsonDecode(response.body);
                    print('📦 Drop location: ${data['drop_location']}');
                    print('📍 Drop coordinates: ${data['drop_latlng']}');
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
          'Booking In Progress',
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
              'Booking ID: ${bookingId ?? "-"}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Pickup Coordinates: (${pickupLat ?? "-"}, ${pickupLng ?? "-"})',
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