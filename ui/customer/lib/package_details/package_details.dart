import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PackageDetailsScreen extends StatefulWidget {
  final BookingData bookingData;
  const PackageDetailsScreen({super.key, required this.bookingData});

  @override
  State<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Package Details'),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Package Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _dimensionsController,
                    decoration: const InputDecoration(
                      labelText: 'Dimensions (L x W x H in cm)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Instructions (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          bottomSheet: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            color: theme.scaffoldBackgroundColor,
            child: ElevatedButton(
              onPressed: () async {
                FocusScope.of(context).unfocus(); // Close keyboard
                if (_formKey.currentState!.validate()) {
                  setState(() => _isLoading = true);
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    widget.bookingData.description = _descriptionController.text;
                    widget.bookingData.weight = _weightController.text;
                    widget.bookingData.dimensions = _dimensionsController.text;
                    widget.bookingData.instructions = _instructionsController.text;
                    widget.bookingData.distanceKm = widget.bookingData.distanceKm;
                    widget.bookingData.customer = '1';
                    print('📦 Booking data: ${jsonEncode(widget.bookingData.toJson())}');
                    final uri = Uri.parse('http://192.168.0.101:8000/api/bookings/start/');

                    final response = await http.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(widget.bookingData.toJson()),
                    );

                    if (response.statusCode == 201) {
                      final responseData = jsonDecode(response.body);
                      final bookingId = responseData['id'];
                      Navigator.pushReplacementNamed(
                        context,
                        '/booking',
                        arguments: {'id': bookingId},
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Booking failed: ${response.statusCode}')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text('Book'),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}