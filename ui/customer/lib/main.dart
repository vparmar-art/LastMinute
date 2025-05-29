import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login/login_screen.dart'; 
import 'home/home_screen.dart';
import 'package_details/package_details.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'booking/booking_screen.dart';

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

void main() {
  runApp(const MyApp());
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
        '/package-details': (context) {
          final bookingData = ModalRoute.of(context)!.settings.arguments as BookingData;
          return PackageDetailsScreen(bookingData: bookingData);
        },
        '/booking': (context) => const BookingScreen(),
      },
    );
  }
}