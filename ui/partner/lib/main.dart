import 'dart:convert';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  String? title = message.notification?.title;
  String? body = message.notification?.body;

  // Try extracting from nested GCM data
  if (title == null || body == null) {
    String? gcmPayload = message.data['GCM'];
    if (gcmPayload != null) {
      try {
        final gcmData = jsonDecode(gcmPayload);
        title = gcmData['notification']?['title'] ?? title;
        body = gcmData['notification']?['body'] ?? body;
      } catch (_) {}
    }
  }

  // Also try extracting from nested 'default' JSON string if GCM missing
  if (title == null || body == null) {
    final defaultPayload = message.data['default'];
    if (defaultPayload != null && defaultPayload is String) {
      try {
        final defaultJson = jsonDecode(defaultPayload);
        final gcmFromDefault = defaultJson['GCM'];
        if (gcmFromDefault != null) {
          final gcmData = jsonDecode(gcmFromDefault);
          title = gcmData['notification']?['title'] ?? title;
          body = gcmData['notification']?['body'] ?? body;
        }
      } catch (_) {}
    }
  }

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title ?? 'Background Notification',
    body ?? '',
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

  print('🔔 Handling a background message: ${message.messageId}, title: $title, body: $body');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔐 Notification permission status: ${settings.authorizationStatus}');

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $fcmToken');

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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
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
      },
    );
  }
}