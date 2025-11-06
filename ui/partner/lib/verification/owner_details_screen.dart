import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';

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
    // Fetch vehicle types first, then owner details
    _fetchVehicleTypes().then((_) {
      _fetchOwnerDetails();
    });
  }

  // Fetch vehicle types
  Future<void> _fetchVehicleTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$apiBaseUrl/vehicles/types/'),
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
      Uri.parse('$apiBaseUrl/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final properties = data['properties'];
      setState(() {
        _ownerFullNameController.text = properties['owner_full_name'] ?? '';
        _vehicleNumberController.text = properties['vehicle_number'] ?? '';
        _registrationNumberController.text = properties['registration_number'] ?? '';

        // Handle vehicle_type as either int (ID) or string (name)
        final fetchedVehicleType = properties['vehicle_type'];
        String? vehicleTypeName;
        
        if (fetchedVehicleType != null) {
          if (fetchedVehicleType is int) {
            // If it's an ID, find the vehicle type by ID
            final vehicleType = _vehicleTypes.firstWhere(
              (v) => v['id'] == fetchedVehicleType,
              orElse: () => {},
            );
            vehicleTypeName = vehicleType['name'];
          } else {
            // If it's already a string/name, use it directly
            vehicleTypeName = fetchedVehicleType.toString();
          }
        }
        
        final exists = vehicleTypeName != null && _vehicleTypes.any((v) => v['name'] == vehicleTypeName);
        _selectedVehicleType = exists ? vehicleTypeName : null;
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

    // Build request body, only include vehicle_type if selected
    final requestBody = <String, dynamic>{
      'owner_full_name': _ownerFullNameController.text,
      'vehicle_number': _vehicleNumberController.text,
      'registration_number': _registrationNumberController.text,
      'current_step': 2
    };
    
    // Only add vehicle_type if it's selected
    if (_selectedVehicleType != null && _selectedVehicleType!.isNotEmpty) {
      requestBody['vehicle_type'] = _selectedVehicleType;
    }

    final response = await http.put(
      Uri.parse('$apiBaseUrl/users/partner/profile/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      print('Owner details saved successfully');
      if (context.mounted) {
        Navigator.pushNamed(context, '/driver-details');
      }
    } else {
      final errorBody = response.body;
      print('Failed to save owner details: ${response.statusCode}');
      print('Error response: $errorBody');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${response.statusCode} - ${errorBody.length > 100 ? errorBody.substring(0, 100) : errorBody}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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