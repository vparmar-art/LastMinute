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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void onDidReceiveNotificationResponse(NotificationResponse response) {
  print('🔔 Notification tapped: ${response.payload}, Action ID: ${response.actionId}');
  if (response.actionId == 'ACCEPT') {
    print('✅ Booking accepted.');
  } else if (response.actionId == 'REJECT') {
    print('❌ Booking rejected.');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final rawPayload = message.data['default'];
  print('Message received: $rawPayload');

  String? title = message.notification?.title;
  String? body = message.notification?.body;

  if (title == null || body == null) {
    try {
      final defaultData = jsonDecode(rawPayload);
      final gcmString = defaultData['GCM'];
      final gcmData = jsonDecode(gcmString);
      final notification = gcmData['notification'];
      title = notification?['title'] ?? title;
      body = notification?['body'] ?? body;
    } catch (e) {
      print('❌ Failed to parse notification: $e');
    }
  }

  print('Background message final title: $title, body: $body');

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
      // fullScreenIntent: true,
      ticker: 'ticker',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_action', // Action ID
          'Accept',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'reject_action', // Action ID
          'Reject',
          showsUserInterface: true,
        ),
      ],
    ),
  ),
  payload: 'booking_id=123',
);

  print('🔔 Handling a background message: ${message.messageId}, title: $title, body: $body');
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔐 Notification permission status: ${settings.authorizationStatus}');

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('FCM Token: $fcmToken');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
      },
    );
  }
}