import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PackageDetailsScreen extends StatefulWidget {
  const PackageDetailsScreen({super.key});

  @override
  State<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
            if (_formKey.currentState!.validate()) {
              final uri = Uri.parse('http://192.168.0.100:8000/api/bookings/start/'); 

              final response = await http.post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'customer': 1,  // Replace with actual customer ID
                  'pickup_location': 'Pickup Location',
                  'drop_location': 'Drop Location',
                  'pickup_time': DateTime.now().toIso8601String(),
                  'drop_time': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
                  'amount': 100.0,
                }),
              );

              if (response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Package booked!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Booking failed: ${response.statusCode}')),
                );
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
    );
  }
}