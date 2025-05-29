import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? booking;
  bool isLoading = true;
  bool hasError = false;

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
    final url = Uri.parse('http://192.168.0.104:8000/api/bookings/$id/');
    print('Fetching booking details for ID: $id from $url');
    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Token YOUR_TOKEN_HERE',
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

  Widget _buildBookingDecisionSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _decisionMaxDrag = constraints.maxWidth - 40;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _decisionDrag += details.primaryDelta ?? 0;
              _decisionDrag = _decisionDrag.clamp(0.0, _decisionMaxDrag);
            });
          },
          onHorizontalDragEnd: (details) async {
            await HapticFeedback.mediumImpact();
            setState(() {
              if (_decisionDrag > _decisionMaxDrag / 2) {
                _isLive = true;
                print('✅ Booking Accepted');
                // Call accept API here
              } else {
                _isLive = false;
                print('❌ Booking Rejected');
                // Call reject API here
              }
              _decisionDrag = 0.0; // Reset the slider
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _isLive ? Colors.green : Colors.red,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (_isLive ? _decisionDrag : (_decisionMaxDrag - _decisionDrag)) / _decisionMaxDrag,
                  child: Center(
                    child: Text(
                      _isLive ? 'Swipe to Reject' : 'Swipe to Accept',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                Positioned(
                  left: _decisionDrag,
                  child: _buildArrowButton(),
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
        title: const Text('Booking Details'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text('Failed to load booking details.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Card(
                        child: ListTile(
                          title: const Text('Pickup Location'),
                          subtitle: Text(booking?['pickup_location'] ?? ''),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Drop Location'),
                          subtitle: Text(booking?['drop_location'] ?? ''),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Status'),
                          subtitle: Text(booking?['status'] ?? ''),
                        ),
                      ),
                      if (booking?['pickup_time'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Pickup Time'),
                            subtitle: Text(booking?['pickup_time']),
                          ),
                        ),
                      if (booking?['drop_time'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Drop Time'),
                            subtitle: Text(booking?['drop_time']),
                          ),
                        ),
                      if (booking?['weight'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Weight'),
                            subtitle: Text('${booking?['weight']} kg'),
                          ),
                        ),
                      if (booking?['dimensions'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Dimensions'),
                            subtitle: Text(booking?['dimensions']),
                          ),
                        ),
                      if (booking?['instructions'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Instructions'),
                            subtitle: Text(booking?['instructions']),
                          ),
                        ),
                      if (booking?['distance_km'] != null)
                        Card(
                          child: ListTile(
                            title: const Text('Distance'),
                            subtitle: Text('${booking?['distance_km']} km'),
                          ),
                        ),
                      _buildBookingDecisionSlider(),
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
    );
  }
}