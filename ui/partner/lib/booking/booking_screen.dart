import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

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
          ],
        ),
      ),
    );
  }
}