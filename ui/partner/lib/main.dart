import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login/login_screen.dart'; 
import 'home/home_screen.dart'; 
import 'verification/owner_details_screen.dart';
import 'verification/driver_details_screen.dart';
import 'verification/verification_screen.dart';
import 'verification/verification_controller.dart';
import 'booking/booking_detail_screen.dart';
import 'booking/pickup_details_screen.dart';
import 'booking/drop_details_screen.dart';
import 'wallet/recharge_screen.dart';
import 'utils/ride_state_manager.dart';

Future<bool> requestLocationPermissions() async {
  var status = await Permission.location.status;
  if (!status.isGranted) {
    status = await Permission.location.request();
    if (!status.isGranted) return false;
  }

  var bgStatus = await Permission.locationAlways.status;
  if (!bgStatus.isGranted) {
    bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) return false;
  }

  return true;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onDidReceiveNotificationResponse(NotificationResponse response) {
  final bookingId = int.tryParse(response.payload?.split('=').last ?? '');
  if (bookingId != null) {
    navigatorKey.currentState?.pushNamed('/booking-detail', arguments: {'id': bookingId});
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final bookingId = message.data['booking_id'];

  // Save ride state in background
  final prefs = await SharedPreferences.getInstance();
  final rideState = {
    'bookingId': int.tryParse(bookingId ?? ''),
    'status': 'created',
    'lastUpdated': DateTime.now().toIso8601String(),
    // Add more fields if you can extract them from the message
  };
  await prefs.setString('current_partner_ride_state', jsonEncode(rideState));

  String? title = message.notification?.title;
  String? body = message.notification?.body;

  if (title == null || body == null) {
    try {
      final rawPayload = message.data['default'];
      final defaultData = jsonDecode(rawPayload);
      final gcmString = defaultData['GCM'];
      final gcmData = jsonDecode(gcmString);
      final notification = gcmData?['notification'];
      title = notification?['title'] ?? title;
      body = notification?['body'] ?? body;
    } catch (e) {
      // print('❌ Failed to parse notification: $e');
    }
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title ?? 'New Notification',
    body ?? 'You received a new message',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_priority_channel',
        'High Priority Notifications',
        channelDescription: 'Notifications shown over other apps',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_alert'), // custom sound
        ticker: 'ticker',
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'view_booking',
            'View',
            showsUserInterface: true,
          ),
        ],
      ),
    ),
    payload: 'booking_id=${bookingId ?? ''}',
  );
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  bool locationGranted = await requestLocationPermissions();
  if (!locationGranted) {
    // print('⚠️ Location permissions not granted.');
    // Optionally handle permission denial here
  } else {
    // print('✅ Location permissions granted.');
  }

  // SharedPreferences persistence test
  final prefs = await SharedPreferences.getInstance();
  // Print the value before writing
  // print('Test key before writing: ${prefs.getString('test_key')}');
  await prefs.setString('test_key', 'test_value');
  // print('Test key after writing: ${prefs.getString('test_key')}');

const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_priority_channel',
    'High Priority Notifications',
    description: 'Notifications shown over other apps',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification_alert'), // custom sound
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  // print('🔐 Notification permission status: ${settings.authorizationStatus}');

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  // print('FCM Token: $fcmToken');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    // print('📨 Full foreground message: ${jsonEncode(message.data)}');
    final rawPayload = message.data['default'];
    // print('📥 Foreground message received: $rawPayload');

    String? title = message.notification?.title;
    String? body = message.notification?.body;
    int? bookingId;

    if (title == null || body == null) {
      try {
        final defaultData = jsonDecode(rawPayload);
        final gcmString = defaultData['GCM'];
        final gcmData = jsonDecode(gcmString);
        final notification = gcmData['notification'];
        title = notification?['title'] ?? title;
        body = notification?['body'] ?? body;

        if (gcmData['data'] != null && gcmData['data']['booking_id'] != null) {
          bookingId = int.tryParse(gcmData['data']['booking_id'].toString());
        }
      } catch (e) {
        // print('❌ Failed to parse notification: $e');
      }
    } else if (message.data['booking_id'] != null) {
      bookingId = int.tryParse(message.data['booking_id'].toString());
    }

    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      title ?? 'New Notification',
      body ?? 'You received a new message',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_priority_channel',
          'High Priority Notifications',
          channelDescription: 'Notifications shown over other apps',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_alert'), // custom sound
        ),
      ),
      payload: 'booking_id=${bookingId ?? ''}',
    );

    if (bookingId != null) {
      // Save ride state when notification is received
      final rideState = PartnerRideState(
        bookingId: bookingId,
        status: 'created', // Default status for new booking
        lastUpdated: DateTime.now(),
      );
      await PartnerRideStateManager.saveRideState(rideState);
      
      navigatorKey.currentState?.pushNamed('/booking-detail', arguments: {'id': bookingId});
    }
  });

  runApp(const MyApp());
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    try {
      if (!mounted) return;
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      print('🚀 SplashScreen: Token found: ${token != null && token.isNotEmpty}');
      
      if (token != null && token.isNotEmpty) {
        // Check if there's an active ride
        print('🚀 SplashScreen: Calling getInitialRouteWithArgs()...');
        final routeInfo = await PartnerRideStateManager.getInitialRouteWithArgs();
        print('🚀 SplashScreen: Route info: $routeInfo');
        
        if (!mounted) return;
        
        // Use addPostFrameCallback to ensure navigation happens after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          if (routeInfo != null) {
            print('🚀 SplashScreen: Navigating to ${routeInfo['route']}');
            try {
              Navigator.pushReplacementNamed(
                context,
                routeInfo['route'],
                arguments: routeInfo['arguments'],
              );
            } catch (e) {
              print('❌ SplashScreen: Navigation error: $e');
              Navigator.pushReplacementNamed(context, '/home');
            }
          } else {
            print('🚀 SplashScreen: No route info, going to home');
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
      } else {
        print('🚀 SplashScreen: No token, going to login');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      }
    } catch (e) {
      print('❌ SplashScreen: Error in _checkLoginStatus: $e');
      // Fallback to home on error
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastMinute',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/owner-details': (context) => const OwnerDetailsScreen(),
        '/driver-details': (context) => const DriverDetailsScreen(),
        '/verify-in-progress': (context) {
          final controller = VerificationController();
          return VerificationScreen(
            isRejected: controller.data.isRejected,
            rejectionReason: controller.data.rejectionReason,
          );
        },
        '/verify': (context) => Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              VerificationController().handleCurrentStep(context);
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
        '/pick-up': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return PickupScreen(key: UniqueKey());
        },
        '/drop': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DropScreen(key: UniqueKey());
        },
        '/booking-detail': (context) => const BookingDetailScreen(),
        '/plans': (context) => const RechargeScreen(),
      },
    );
  }
}