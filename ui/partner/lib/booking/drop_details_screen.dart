import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../utils/ride_state_manager.dart';

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
  String? dropOtp;
  bool _isValidating = true;
  bool _isValidBooking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          bookingId = args['booking_id'] ?? args['id'];
          dropAddress = args['drop_location'] ?? args['drop_address'];
          dropOtp = args['drop_otp'] ?? dropOtp;
          if (args['drop_latlng'] != null) {
            dropLatitude = args['drop_latlng']['lat'] ?? args['drop_latlng']['coordinates']?[1];
            dropLongitude = args['drop_latlng']['lng'] ?? args['drop_latlng']['coordinates']?[0];
          } else {
            dropLatitude = args['drop_lat'] ?? dropLatitude;
            dropLongitude = args['drop_lng'] ?? dropLongitude;
          }
        });
      }
      // Validate booking after loading arguments
      _validateBooking();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    int? bookingId = args?['id'];
    String? dropAddress = args?['drop_address'];
    String? dropOtp = args?['drop_otp'];
    double? dropLat = args?['drop_lat'];
    double? dropLng = args?['drop_lng'];
    
    // Set lat/lng from arguments if provided
    if (dropLat != null && dropLng != null) {
      setState(() {
        dropLatitude = dropLat;
        dropLongitude = dropLng;
      });
    }
    
    _restoreRideState(bookingId, dropAddress, dropOtp);
  }

  Future<void> _restoreRideState(int? bookingId, String? dropAddress, String? dropOtp) async {
    final rideState = await PartnerRideStateManager.getRideState();
    if (rideState != null && rideState.isActive && (bookingId == null || rideState.bookingId == bookingId)) {
      setState(() {
        // Use arguments if present, else fallback to ride state
        this.bookingId = rideState.bookingId;
        this.dropAddress = dropAddress ?? rideState.dropLocation;
        this.dropOtp = dropOtp ?? rideState.dropOtp;
        // Restore lat/lng from ride state if not already set
        if (dropLatitude == null && rideState.dropLat != null) {
          dropLatitude = rideState.dropLat;
        }
        if (dropLongitude == null && rideState.dropLng != null) {
          dropLongitude = rideState.dropLng;
        }
      });
      // Validate booking after restoring state
      _validateBooking();
    } else if (rideState != null && !rideState.isActive) {
      // Clear stale ride state
      await PartnerRideStateManager.clearRideState();
      _redirectToHome();
    }
  }

  Future<void> _validateBooking() async {
    if (bookingId == null) {
      setState(() {
        _isValidating = false;
        _isValidBooking = false;
      });
      _redirectToHome();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/bookings/$bookingId/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final booking = jsonDecode(response.body);
        final status = booking['status'] as String?;
        
        // Check if booking is in a valid state for drop screen
        // Drop screen should only show for 'in_transit' status
        if (status == 'in_transit') {
          setState(() {
            _isValidating = false;
            _isValidBooking = true;
          });
        } else {
          // Booking is not in transit, clear state and redirect
          await PartnerRideStateManager.clearRideState();
          setState(() {
            _isValidating = false;
            _isValidBooking = false;
          });
          _redirectToHome();
        }
      } else {
        // Booking not found or error
        await PartnerRideStateManager.clearRideState();
        setState(() {
          _isValidating = false;
          _isValidBooking = false;
        });
        _redirectToHome();
      }
    } catch (e) {
      print('Error validating booking: $e');
      // On error, allow user to stay but show warning
      setState(() {
        _isValidating = false;
        _isValidBooking = true; // Allow user to try
      });
    }
  }

  void _redirectToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<void> _persistRideState(String status) async {
    final rideState = PartnerRideState(
      bookingId: bookingId,
      status: status,
      dropLocation: dropAddress,
      dropOtp: dropOtp,
      dropLat: dropLatitude,
      dropLng: dropLongitude,
      lastUpdated: DateTime.now(),
    );
    await PartnerRideStateManager.saveRideState(rideState);
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
                    // Clear ride state when trip is completed
                    await PartnerRideStateManager.clearRideState();
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
    // Show loading while validating
    if (_isValidating) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Drop Location',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.indigo,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validating booking...'),
            ],
          ),
        ),
      );
    }

    // Show error if booking is invalid
    if (!_isValidBooking) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Drop Location',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.indigo,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No active booking found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Redirecting to home...'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Drop Location',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Don't allow going back, only forward
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please complete the trip or contact support'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
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
