import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? booking;
  bool isLoading = true;
  bool hasError = false;
  bool isUpdating = false;

  double _decisionDrag = 0.0;
  late double _decisionMaxDrag;
  bool _isLive = false;

  Widget _buildArrowButton() {
    return Container(
      height: 40,
      width: 40,
      alignment: Alignment.center,
      child: Icon(
        _isLive ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final bookingId = args['id'] as int;
    fetchBookingDetails(bookingId);
  }

  Future<void> fetchBookingDetails(int id) async {
    final url = Uri.parse('http://prod-lb-1625394403.us-east-1.elb.amazonaws.com/api/bookings/$id/');
    print('Fetching booking details for ID: $id from $url');
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(url, headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      });
      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('Response body: ${response.body}');
        setState(() {
          booking = json.decode(response.body);
          isLoading = false;
        });
      } else {
        print('Failed to load booking details: ${response.reasonPhrase}');
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching booking details: $e');
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> updateBookingStatus(int bookingId, String status) async {
    setState(() {
      isUpdating = true;
    });

    try {
      final url = Uri.parse('http://prod-lb-1625394403.us-east-1.elb.amazonaws.com/api/bookings/$bookingId/status/');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': status}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('Booking status updated to $status');
        await fetchBookingDetails(bookingId);

        if (status == 'arriving' && mounted) {
          final pickupLatLng = booking?['pickup_latlng']?['coordinates'];
          final pickupAddress = booking?['pickup_location'];
          Navigator.pushReplacementNamed(
            context,
            '/pick-up',
            arguments: {
              'id': bookingId,
              'pickup_lat': pickupLatLng != null ? pickupLatLng[1] : null,
              'pickup_lng': pickupLatLng != null ? pickupLatLng[0] : null,
              'pickup_address': pickupAddress,
            },
          );
        }
      } else {
        print('Failed to update booking status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating booking status: $e');
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Widget _buildBookingDecisionSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _decisionMaxDrag = constraints.maxWidth;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _decisionDrag += details.primaryDelta ?? 0;
              _decisionDrag = _decisionDrag.clamp(-_decisionMaxDrag / 2, _decisionMaxDrag / 2);
            });
          },
          onHorizontalDragEnd: (details) async {
            await HapticFeedback.mediumImpact();
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            final bookingId = args['id'] as int;
            if (_decisionDrag > _decisionMaxDrag / 4) {
              await updateBookingStatus(bookingId, 'arriving');
            } else if (_decisionDrag < -_decisionMaxDrag / 4) {
              print('❌ Booking Rejected');
              // You can add reject API call here
            }

            setState(() {
              _decisionDrag = 0.0;
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.red],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 1.0 - (_decisionDrag.abs() / (_decisionMaxDrag / 2)).clamp(0.0, 1.0),
                  child: const Text(
                    'Accept / Reject',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Positioned(
                  left: 10 + (_decisionDrag > 0 ? _decisionDrag : 0),
                  child: _buildArrowButton(),
                ),
                Positioned(
                  right: 10 + (_decisionDrag < 0 ? -_decisionDrag : 0),
                  child: Transform.rotate(
                    angle: 3.14,
                    child: _buildArrowButton(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Booking Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            color: Colors.grey[100],
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasError
                    ? const Center(child: Text('Failed to load booking details.'))
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: ListView(
                          children: [
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                title: const Text('Pickup Location'),
                                subtitle: Text(booking?['pickup_location'] ?? ''),
                              ),
                            ),
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                title: const Text('Drop Location'),
                                subtitle: Text(booking?['drop_location'] ?? ''),
                              ),
                            ),
                            // Amount card inserted after Drop Location
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                title: const Text('Amount'),
                                subtitle: Text('₹${booking?['amount'] ?? '0'}'),
                              ),
                            ),
                            if (booking?['pickup_time'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Pickup Time'),
                                  subtitle: Text(booking?['pickup_time']),
                                ),
                              ),
                            if (booking?['drop_time'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Drop Time'),
                                  subtitle: Text(booking?['drop_time']),
                                ),
                              ),
                            if (booking?['weight'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Weight'),
                                  subtitle: Text('${booking?['weight']} kg'),
                                ),
                              ),
                            if (booking?['dimensions'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Dimensions'),
                                  subtitle: Text(booking?['dimensions']),
                                ),
                              ),
                            if (booking?['instructions'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Instructions'),
                                  subtitle: Text(booking?['instructions']),
                                ),
                              ),
                            if (booking?['distance_km'] != null)
                              Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                child: ListTile(
                                  title: const Text('Distance'),
                                  subtitle: Text('${booking?['distance_km']} km'),
                                ),
                              ),
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildBookingDecisionSlider(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            /*
                            ElevatedButton(
                              onPressed: () {
                                // Future implementation: update status, etc.
                              },
                              child: const Text('Update Booking'),
                            ),
                            */
                          ],
                        ),
                      ),
          ),
          if (isUpdating)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}