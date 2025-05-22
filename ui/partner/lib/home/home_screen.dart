import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

// Add these imports
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "App is running",
      content: "Background location service is active",
    );
    service.setAsForegroundService();
  }

  service.on('setAsForeground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }
  });

  service.on('setAsBackground').listen((event) {
    if (service is AndroidServiceInstance) {
      service.setAsBackgroundService();
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        Uri.parse('http://192.168.0.101:8000/api/users/partner/update-location/'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        print('🔄 Background location updated successfully');
      } else {
        print('❌ Failed to update location: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 Error updating location: $e');
    }
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLive = false;
  double _dragPosition = 0.0;
  double _maxDrag = 0.0;
  int _totalBookings = 0;
  double _totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();

    _fetchPartnerDetails();
    _fetchTotalBookings();
  }

  void _startBackgroundLocationUpdates() {
    initializeService();
    print("🚀 Background location service started");
  }

  void _stopBackgroundLocationUpdates() {
    FlutterBackgroundService().invoke("stopService");
    print("🛑 Background location service stopped");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Driver Home',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome, Driver!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Total Earnings Today', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('₹${_totalEarnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: const [
                    Text('Live Hours', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text('0h 0m', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Total Bookings', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text('$_totalBookings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildLiveToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveToggle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - 40;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragPosition += details.primaryDelta ?? 0;
              _dragPosition = _dragPosition.clamp(0.0, _maxDrag);
            });
          },
          onHorizontalDragEnd: (details) async {
            await HapticFeedback.mediumImpact();
            setState(() {
              if (_dragPosition > _maxDrag / 2) {
                _isLive = true;
                _dragPosition = _maxDrag;
                _startBackgroundLocationUpdates();
              } else {
                _isLive = false;
                _dragPosition = 0;
                _stopBackgroundLocationUpdates();
              }
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _isLive ? Colors.red : Colors.green,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (_isLive ? _dragPosition : (_maxDrag - _dragPosition)) / _maxDrag,
                  child: Center(
                    child: Text(
                      _isLive ? 'Swipe to go Offline' : 'Swipe to go Live',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                Positioned(
                  left: _dragPosition,
                  child: _buildArrowButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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

  Future<void> _fetchPartnerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.0.101:8000/api/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Partner Profile Response: $data');
      final isApproved = data['profile']['is_verified'] == true;
      if (!isApproved && mounted) {
        Navigator.pushReplacementNamed(context, '/verify');
      }
    }
  }

  Future<void> _fetchTotalBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.0.101:8000/api/bookings/list/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _totalBookings = data.length;
        _totalEarnings = data.fold<double>(0.0, (sum, booking) {
          return sum + double.tryParse(booking['amount'] ?? '0')!;
        });
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}