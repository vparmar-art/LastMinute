import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isLive = false;
  double _dragPosition = 0.0;
  double _maxDrag = 0.0;
  int _totalBookings = 0;
  double _totalEarnings = 0.0;
  String _notificationMessage = 'No new messages';

  @override
  void initState() {
    super.initState();
    _fetchPartnerDetails();
    _fetchTotalBookings();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('🔥 Foreground message received');
      print('Full message data: ${message.data}');

      String? gcmPayload;

      // Try to find GCM payload from top-level or nested in 'default'
      if (message.data['GCM'] != null) {
        gcmPayload = message.data['GCM'];
      } else if (message.data['default'] != null) {
        try {
          final defaultJson = jsonDecode(message.data['default']);
          gcmPayload = defaultJson['GCM'];
        } catch (e) {
          print('❌ Error parsing message.data["default"]: $e');
        }
      }

      Map<String, dynamic>? gcmData;
      if (gcmPayload != null) {
        try {
          gcmData = jsonDecode(gcmPayload);
        } catch (e) {
          print('❌ Error decoding GCM payload: $e');
        }
      }

      final title = gcmData?['notification']?['title'] ?? message.notification?.title ?? '[No Title]';
      final body = gcmData?['notification']?['body'] ?? message.notification?.body ?? '[No Body]';

      print('🔔 Title: $title');
      print('📦 Data: ${gcmData ?? message.data}');

      if (!mounted) return;
      setState(() {
        _notificationMessage = 'Title: $title\nBody: $body';
      });

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel',
            'General Notifications',
            channelDescription: 'This channel is used for general notifications.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
        ),
      );
    });
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
            Card(
              color: Colors.amber.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _notificationMessage,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
              } else {
                _isLive = false;
                _dragPosition = 0;
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
      Uri.parse('http://192.168.0.100:8000/api/users/partner/profile/'),
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
      Uri.parse('http://192.168.0.100:8000/api/bookings/list/'),
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