import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'homepage.dart';
import 'product_detail.dart';
import 'login.dart';

void main() => runApp(const EcomApp());

class EcomApp extends StatelessWidget {
  const EcomApp({super.key});

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final customerId = prefs.getInt('customer_id');
    print('🔐 Token: $token');
    print('🧑‍💼 Customer ID: $customerId');
    return token != null && customerId != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastMinute Store',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Builder(
        builder: (context) {
          _checkLoginStatus().then((isLoggedIn) {
            final route = isLoggedIn ? '/home' : '/login';
            Navigator.pushReplacementNamed(context, route);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/product/')) {
          final id = int.tryParse(settings.name!.split('/product/').last);
          if (id != null) {
            return MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: id),
            );
          }
        }
        return null;
      },
    );
  }
}