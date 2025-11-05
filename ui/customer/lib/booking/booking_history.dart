import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getInt('customer');
    if (customerId == null) return;

    final url = Uri.parse('$apiBaseUrl/bookings/list/?customer=$customerId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        _bookings = jsonDecode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load bookings')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text('No past bookings found.'))
              : ListView.builder(
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.local_shipping),
                        title: Text('From: ${booking['pickup_location']}'),
                        subtitle: Text('To: ${booking['drop_location']}'),
                        trailing: Text('₹${booking['amount']}'),
                    ),
                );
            },
        ),
    );
  }
}