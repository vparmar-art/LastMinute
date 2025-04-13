import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _fetchPartnerDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      body: const Center(
        child: Text(
          'Welcome, Driver!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Future<void> _fetchPartnerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.29.86:8000/api/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final isApproved = data['profile']['is_approved'] == true;
      if (!isApproved && mounted) {
        Navigator.pushReplacementNamed(context, '/verify');
      }
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