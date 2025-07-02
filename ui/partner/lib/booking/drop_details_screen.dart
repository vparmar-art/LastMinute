import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';

class DropScreen extends StatefulWidget {
  const DropScreen({super.key});

  @override
  State<DropScreen> createState() => _DropScreenState();
}

class _DropScreenState extends State<DropScreen> {
  int? bookingId;
  double? dropLatitude;
  double? dropLongitude;
  String? dropAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          bookingId = args['booking_id'];
          dropAddress = args['drop_location'];
          dropLatitude = args['drop_latlng']['lat'] ?? args['drop_latlng']['coordinates'][1];
          dropLongitude = args['drop_latlng']['lng'] ?? args['drop_latlng']['coordinates'][0];
        });
        print('📦 DropScreen args: id=$bookingId, dropLat=$dropLatitude, dropLng=$dropLongitude, dropAddress=$dropAddress');
      }
    });
  }

  void _launchNavigation() async {
    if (dropLatitude != null && dropLongitude != null) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$dropLatitude,$dropLongitude');
      try {
        await launcher.launchUrl(url, mode: launcher.LaunchMode.externalApplication);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
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

                print('✅ Drop OTP entered: $enteredOtp');
                try {
                  final response = await http.post(
                    Uri.parse('$apiBaseUrl/bookings/validate-drop-otp/'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'booking_id': bookingId,
                      'otp': enteredOtp,
                    }),
                  );

                  print('🔁 Drop OTP Response: ${response.statusCode}');
                  print('🔁 Response Body: ${response.body}');

                  if (response.statusCode == 200) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('❌ Invalid OTP. Please try again.')),
                    );
                  }
                } catch (e) {
                  print('Error: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Error validating OTP')),
                  );
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
          'Drop Location',
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
              'Drop Coordinates: (${dropLatitude ?? "-"}, ${dropLongitude ?? "-"})',
            ),
            const SizedBox(height: 10),
            if (dropAddress != null)
              Text(
                'Drop Address: $dropAddress',
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
              onPressed: _showOtpDialog,
              icon: const Icon(Icons.check_circle),
              label: const Text('End Trip'),
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
