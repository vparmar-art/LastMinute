import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Timer? _pollingTimer;
  bool _isArriving = false;
  int? bookingId;
  bool _isLoading = true;
  String _partnerName = '';
  String _driverPhone = '';
  String _vehicleNumber = '';
  String _vehicleType = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (bookingId == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      bookingId = args?['id'];
      print('Booking ID received in BookingScreen: $bookingId');
      if (bookingId != null) {
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchBooking());
  }

  Future<void> _fetchBooking() async {
    print('🔄 Fetching booking status for ID: $bookingId');
    final url = Uri.parse('http://192.168.0.101:8000/api/bookings/$bookingId/');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'arriving') {
          final partnerId = data['partner'];
          await _fetchPartnerProfile(partnerId); // fetch partner details
          if (mounted) {
            setState(() {
              _isArriving = true;
              _isLoading = false;
            });
          }
          _pollingTimer?.cancel();
        }
      } else {
        print('Error fetching booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _fetchPartnerProfile(int partnerId) async {
    final url = Uri.parse('http://192.168.0.101:8000/api/users/partner/profile/?id=$partnerId');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        print('📦 Partner profile response: ${response.body}');
        final data = json.decode(response.body);
        final properties = data['properties'];
        final geometry = data['geometry'];
        _partnerName = properties['driver_name'] ?? '';
        _driverPhone = properties['driver_phone']?.toString() ?? '';
        _vehicleNumber = properties['vehicle_number'] ?? '';
        _vehicleType = properties['vehicle_type'] ?? '';
        final coords = geometry['coordinates'];
        _lng = coords[0];
        _lat = coords[1];
      } else {
        print('Error fetching partner profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching partner profile: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_lat != null && _lng != null)
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_lat!, _lng!),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('driver'),
                        position: LatLng(_lat!, _lng!),
                        infoWindow: InfoWindow(
                          title: _partnerName,
                          snippet: '$_vehicleType ($_vehicleNumber)',
                        ),
                      ),
                    },
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your driver $_partnerName is on the way',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text('Phone: $_driverPhone'),
                        Text('Vehicle: $_vehicleType ($_vehicleNumber)'),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Add call or help support
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Contact Driver'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
