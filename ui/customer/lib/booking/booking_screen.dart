import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Timer? _pollingTimer;
  bool _isArriving = false;
  int? bookingId;

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
    final url = Uri.parse('http://192.168.0.104:8000/api/bookings/$bookingId/');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'arriving') {
          setState(() {
            _isArriving = true;
          });
          _pollingTimer?.cancel();
        }
      } else {
        print('Error fetching booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
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
      body: Center(
        child: _isArriving
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Driver has accepted the booking.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Booking ID: $bookingId',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
