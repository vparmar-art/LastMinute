import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({super.key});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _driverLicenseController = TextEditingController();

  @override
  void dispose() {
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _driverLicenseController.dispose();
    super.dispose();
  }

  // Fetch existing driver details
  Future<void> _fetchDriverDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.29.86:8000/api/users/partner/verification/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _driverNameController.text = data['driver_name'] ?? '';
        _driverPhoneController.text = data['driver_phone'] ?? '';
        _driverLicenseController.text = data['driver_license'] ?? '';
      });
    } else {
      print('Failed to fetch driver details');
    }
  }

  // Save driver details
  Future<void> _saveDriverDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.post(
      Uri.parse('http://192.168.29.86:8000/api/users/partner/verification/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',  // Ensure this header is set
      },
      body: json.encode({
        'driver_name': _driverNameController.text,
        'driver_phone': _driverPhoneController.text,
        'driver_license': _driverLicenseController.text,
      }),
    );

    if (response.statusCode == 200) {
      print('Driver details saved successfully');
      if (context.mounted) {
        Navigator.pushNamed(context, '/verify-im-progress');
      }
    } else {
      print('Failed to save driver details');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDriverDetails();  // Fetch existing details if any
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Driver Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _driverNameController,
                decoration: const InputDecoration(
                  labelText: 'Driver Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _driverPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Driver Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _driverLicenseController,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveDriverDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}