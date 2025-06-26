import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DriverDetailsScreen extends StatefulWidget {
  const DriverDetailsScreen({super.key});

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final _driverNameController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  File? _selfieImage;

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
      Uri.parse('http://prod-lb-1092214212.us-east-1.elb.amazonaws.com/api/users/partner/profile/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final properties = data['properties'];
      setState(() {
        _driverNameController.text = properties['driver_name'] ?? '';
        _driverPhoneController.text = properties['driver_phone'] ?? '';
        _driverLicenseController.text = properties['driver_license'] ?? '';
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

    final uri = Uri.parse('http://prod-lb-1092214212.us-east-1.elb.amazonaws.com/api/users/partner/profile/');
    final request = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Token $token'
      ..fields['driver_name'] = _driverNameController.text
      ..fields['driver_phone'] = _driverPhoneController.text
      ..fields['driver_license'] = _driverLicenseController.text
      ..fields['current_step'] = '3';

    if (_selfieImage != null) {
      request.files.add(await http.MultipartFile.fromPath('selfie', _selfieImage!.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Driver details saved successfully');
      if (context.mounted) {
        Navigator.pushNamed(context, '/verify-in-progress');
      }
    } else {
      print('Failed to save driver details');
    }
  }

  Future<void> _pickSelfie() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);

    if (pickedFile != null) {
      setState(() {
        _selfieImage = File(pickedFile.path);
      });
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickSelfie,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: _selfieImage != null ? FileImage(_selfieImage!) : null,
                        backgroundColor: Colors.grey[300],
                        child: _selfieImage == null
                            ? Icon(Icons.camera_alt, size: 40, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to take a selfie',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
      ),
    );
  }
}