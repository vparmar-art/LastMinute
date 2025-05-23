import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OwnerDetailsScreen extends StatefulWidget {
  const OwnerDetailsScreen({super.key});

  @override
  State<OwnerDetailsScreen> createState() => _OwnerDetailsScreenState();
}

class _OwnerDetailsScreenState extends State<OwnerDetailsScreen> {
  String? _selectedVehicleType;
  List<Map<String, dynamic>> _vehicleTypes = [];
  final _ownerFullNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVehicleTypes();
    _fetchOwnerDetails();
  }

  // Fetch vehicle types
  Future<void> _fetchVehicleTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.0.101:8000/api/vehicles/types/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _vehicleTypes = data.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } else {
      print('Failed to fetch vehicle types');
    }
  }

  // Fetch existing owner details
  Future<void> _fetchOwnerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('http://192.168.0.101:8000/api/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
      _ownerFullNameController.text = data['owner_full_name'] ?? '';
      _vehicleNumberController.text = data['vehicle_number'] ?? '';
      _registrationNumberController.text = data['registration_number'] ?? '';

      // Only set _selectedVehicleType if it exists in the fetched list
      final fetchedVehicleType = data['vehicle_type'];
      final exists = _vehicleTypes.any((v) => v['name'] == fetchedVehicleType);
      _selectedVehicleType = exists ? fetchedVehicleType : null;
    });
    } else {
      print('Failed to fetch owner details');
    }
  }

  // Save owner details
  Future<void> _saveOwnerDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.put(
      Uri.parse('http://192.168.0.101:8000/api/users/partner/profile/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',  // Ensure this header is set
      },
      body: json.encode({
        'owner_full_name': _ownerFullNameController.text,
        'vehicle_type': _selectedVehicleType,
        'vehicle_number': _vehicleNumberController.text,
        'registration_number': _registrationNumberController.text,
        'current_step': 2
      }),
    );

    if (response.statusCode == 200) {
      print('Owner details saved successfully');
      if (context.mounted) {
        Navigator.pushNamed(context, '/driver-details');
      }
    } else {
      print('Failed to save owner details');
    }
  }

  @override
  void dispose() {
    _ownerFullNameController.dispose();
    _vehicleNumberController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Owner Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('auth_token');
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _ownerFullNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedVehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                hint: const Text("Select Vehicle Type"), // Add this line
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedVehicleType = newValue;
                  });
                },
                items: _vehicleTypes.map<DropdownMenuItem<String>>((vehicle) {
                  final String name = vehicle['name'] ?? '';
                  final String label = name.replaceAll('_', ' ').toUpperCase();
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _registrationNumberController,
                decoration: const InputDecoration(
                  labelText: 'Registration Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveOwnerDetails,
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