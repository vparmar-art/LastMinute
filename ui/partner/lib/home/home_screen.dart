import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../constants.dart';
import '../main.dart' show navigatorKey;
import '../utils/ride_state_manager.dart';


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

  final prefs = await SharedPreferences.getInstance();
  final partnerId = prefs.getInt('partner_id');

  if (partnerId != null) {
    _connectWebSocketWithRetry(partnerId);
  }
}

void _connectWebSocketWithRetry(int partnerId) async {
  const retryDelay = Duration(seconds: 5);
  const minDistance = 10.0; // meters

  double? lastLat;
  double? lastLng;

    while (true) {
    Timer? locationTimer;
    try {
      final wsUrl = '$wsBaseUrl/users/partner/$partnerId/location/';
      print('🔌 Connecting to WebSocket: $wsUrl');
      final channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );
      print('✅ WebSocket connected successfully');

      locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        try {
          Position position = await Geolocator.getCurrentPosition();
          double lat = position.latitude;
          double lng = position.longitude;

          if (lastLat == null || lastLng == null ||
              Geolocator.distanceBetween(lastLat!, lastLng!, lat, lng) >= minDistance) {
            channel.sink.add(jsonEncode({
              'lat': lat,
              'lng': lng,
            }));
            print('📡 Location sent via WebSocket');
            lastLat = lat;
            lastLng = lng;
          } else {
            print('🛑 Partner has not moved enough, not sending update.');
          }
        } catch (e) {
          print("⚠️ Error getting location or sending via WebSocket: $e");
        }
      });

      await channel.sink.done;
      print("🔌 WebSocket disconnected. Retrying...");
    } catch (e) {
      print("❌ WebSocket connection failed: $e");
    } finally {
      // Cancel the timer before retrying
      locationTimer?.cancel();
    }

    await Future.delayed(retryDelay);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WebSocketChannel? _channel;
  bool _isLive = false;
  String _partnerName = '';
  double _dragPosition = 0.0;
  double _maxDrag = 0.0;
  int _totalBookings = 0;
  double _totalEarnings = 0.0;
  bool _isLoadingProfile = true;
  bool _isSliderInitialized = false;
  int _ridesRemaining = 0;
  double _walletBalance = 0.0;
  String? _walletValidUntil;

  @override
  void initState() {
    FlutterBackgroundService().invoke("stopService");
    print("🧹 Cleared existing background services");
    super.initState();

    _fetchPartnerDetails();
    _fetchTotalBookings();
  }

  void _startBackgroundLocationUpdates() async {
    _checkAndRequestPermissions();
    initializeService();

    final prefs = await SharedPreferences.getInstance();
    final partnerId = prefs.getInt('partner_id');
    if (partnerId != null) {
      final wsUrl = '$wsBaseUrl/users/partner/$partnerId/location/';
      print('🔌 Connecting to WebSocket: $wsUrl');
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );
      print('✅ WebSocket connected successfully');
    } else {
      print('⚠️ Partner ID not found, cannot connect WebSocket');
    }

    print("🚀 Background location service started");
  }

  void _stopBackgroundLocationUpdates() {
    _channel?.sink.close();
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
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Welcome, $_partnerName!',
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
                        const SizedBox(height: 10),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text('Rides Remaining', style: TextStyle(fontSize: 16)),
                                SizedBox(height: 8),
                                Text('$_ridesRemaining', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                                Text('Wallet Balance', style: TextStyle(fontSize: 16)),
                                SizedBox(height: 8),
                                Text('₹${_walletBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                                Text('Plan Validity', style: TextStyle(fontSize: 16)),
                                SizedBox(height: 8),
                                Text(
                                  _walletValidUntil != null
                                      ? DateFormat("d'th' MMMM, y").format(DateTime.parse(_walletValidUntil!)).replaceAll('1th', '1st').replaceAll('2th', '2nd').replaceAll('3th', '3rd')
                                      : 'No Plans',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildLiveToggle(),
                ),
              ],
            ),
    );
  }

  Widget _buildLiveToggle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - 40;

        if (!_isSliderInitialized && _maxDrag > 0) {
          _dragPosition = _isLive ? _maxDrag : 0.0;
          _isSliderInitialized = true;
        }

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragPosition += details.primaryDelta ?? 0;
              _dragPosition = _dragPosition.clamp(0.0, _maxDrag);
            });
          },
          onHorizontalDragEnd: (details) async {
            await HapticFeedback.mediumImpact();

            bool goingLive = _dragPosition > _maxDrag / 2;

            if (goingLive != _isLive) {
              setState(() {
                _isLoadingProfile = true;
              });

              bool success;
              if (goingLive) {
                success = await _updateLiveStatus(true);
                if (success) {
                  _startBackgroundLocationUpdates();
                }
              } else {
                _stopBackgroundLocationUpdates();
                success = await _updateLiveStatus(false);
              }

              setState(() {
                _isLoadingProfile = false;
              });

              if (mounted && success) {
                setState(() {
                  _isLive = goingLive;
                  _dragPosition = goingLive ? _maxDrag : 0.0;
                });
              } else if (mounted && !success && goingLive) {
                // If going live failed (likely due to no active plan), reset the drag position
                setState(() {
                  _dragPosition = 0.0;
                });
                // Navigation to /plans should already be handled in _updateLiveStatus
                // Don't navigate again here to avoid duplicate navigation
              } else if (mounted) {
                setState(() {
                  _dragPosition = _isLive ? _maxDrag : 0.0;
                });
              }
            } else {
              // Snap back if no state change
              setState(() {
                _dragPosition = _isLive ? _maxDrag : 0.0;
              });
            }
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _dragPosition == 0.0
                  ? Colors.red
                  : (_dragPosition == _maxDrag ? Colors.green : null),
              gradient: (_dragPosition != 0.0 && _dragPosition != _maxDrag)
                  ? LinearGradient(
                      colors: [Colors.green, Colors.red],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: [
                        ((_dragPosition / _maxDrag) - 0.2).clamp(0.0, 1.0),
                        ((_dragPosition / _maxDrag) + 0.2).clamp(0.0, 1.0),
                      ],
                    )
                  : null,
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

  Future<bool> _updateLiveStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return false;

    final response = await http.put(
      Uri.parse('$apiBaseUrl/users/partner/profile/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_live': value}),
    );

    if (response.statusCode == 200) {
      print('✅ Live status updated to $value');
      return true;
    } else if (response.statusCode == 403) {
      print('❌ No active plan. Navigating to plans page...');
      // Use navigatorKey for safe navigation that works even if widget is disposed
      // This avoids the "Looking up a deactivated widget's ancestor" error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            print('✅ Navigator found, navigating to /plans...');
            navigator.pushNamed('/plans').then((_) {
              print('✅ Successfully navigated to plans page');
            }).catchError((error) {
              print('❌ Navigation to plans failed: $error');
            });
          } else {
            print('⚠️ Navigator not available (navigatorKey.currentState is null), cannot navigate to plans');
            // Try using context as fallback if widget is still mounted
            if (mounted) {
              print('⚠️ Trying fallback navigation using context...');
              try {
                Navigator.pushNamed(context, '/plans');
              } catch (e) {
                print('❌ Fallback navigation also failed: $e');
              }
            }
          }
        } catch (e) {
          print('❌ Error navigating to plans: $e');
          print('Error stack trace: ${StackTrace.current}');
        }
      });
      return false;
    } else {
      final errorBody = response.body;
      print('❌ Failed to update live status: ${response.statusCode}');
      print('Error response: $errorBody');
      return false;
    }
  }

  Future<void> _fetchPartnerDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
        return;
      }

      print('📡 Fetching partner profile from: $apiBaseUrl/users/partner/profile/');
      final response = await http.get(
        Uri.parse('$apiBaseUrl/users/partner/profile/'),
        headers: {'Authorization': 'Token $token'},
      ).timeout(const Duration(seconds: 10));

      print('📡 Partner profile response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Partner Profile Response: $data');
        final properties = data['properties'];
        final isApproved = properties['is_verified'] == true;
        if (!isApproved && mounted) {
          Navigator.pushReplacementNamed(context, '/verify');
          return;
        } else {
          final partnerId = data['id'];
          await prefs.setInt('partner_id', partnerId);
          
          try {
            final walletResponse = await http.get(
              Uri.parse('$apiBaseUrl/wallet/partner-wallet/$partnerId/'),
              headers: {'Authorization': 'Token $token'},
            ).timeout(const Duration(seconds: 10));

            if (walletResponse.statusCode == 200) {
              final walletData = json.decode(walletResponse.body);
              print('Partner Wallet: $walletData');
              if (mounted) {
                setState(() {
                  _ridesRemaining = walletData['rides_remaining'] ?? 0;
                  _walletBalance = double.tryParse(walletData['balance'].toString()) ?? 0.0;
                  _walletValidUntil = walletData['valid_until'];
                });
              }
            }
          } catch (walletError) {
            print('⚠️ Error fetching wallet: $walletError');
            // Continue even if wallet fetch fails
          }

          if (mounted) {
            setState(() {
              _isLive = properties['is_live'] ?? false;
              _partnerName = properties['driver_name'] ?? properties['owner_full_name'] ?? '';
              _isLoadingProfile = false;
              if (properties['is_live'] == true) {
                _startBackgroundLocationUpdates();
              }
            });
          }
        }
      } else if (response.statusCode == 401) {
        // Token is invalid or expired - clear it and redirect to login
        print('❌ Invalid token (401) - clearing token and redirecting to login');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('partner_id');
        // Clear any stale ride state
        await PartnerRideStateManager.clearRideState();
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        print('❌ Failed to fetch partner profile: ${response.statusCode} - ${response.body}');
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error in _fetchPartnerDetails: $e');
      // Always set loading to false on error
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _fetchTotalBookings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;
    final partnerId = prefs.getInt('partner_id');
    if (partnerId == null) return;

    final response = await http.get(
      Uri.parse('$apiBaseUrl/bookings/list/?partner=$partnerId'),
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
  Future<void> _checkAndRequestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        print("📛 Location permission not granted");
        return;
      }
    }

    final serviceStatus = await Geolocator.isLocationServiceEnabled();
    if (!serviceStatus) {
      print("📛 Location services are disabled");
      return;
    }

    print("✅ Location permissions granted and service enabled");
  }