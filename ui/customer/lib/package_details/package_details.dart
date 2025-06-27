import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class PackageDetailsScreen extends StatefulWidget {
  final BookingData bookingData;
  const PackageDetailsScreen({super.key, required this.bookingData});

  @override
  State<PackageDetailsScreen> createState() => _PackageDetailsScreenState();
}

class _PackageDetailsScreenState extends State<PackageDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _boxesController = TextEditingController(text: '0');
  bool _helperRequired = false;

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
                    controller: _instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Instructions (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _boxesController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Boxes',
                            border: OutlineInputBorder(),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove),
                                  onPressed: () {
                                    int current = int.tryParse(_boxesController.text) ?? 0;
                                    if (current > 0) {
                                      _boxesController.text = (current - 1).toString();
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () {
                                    int current = int.tryParse(_boxesController.text) ?? 0;
                                    _boxesController.text = (current + 1).toString();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          const Text("Helper"),
                          Checkbox(
                            value: _helperRequired,
                            onChanged: (val) {
                              setState(() {
                                _helperRequired = val ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From: ${widget.bookingData.pickupAddress}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('To: ${widget.bookingData.dropAddress}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 12),
                          Text(
                            'Vehicle: ${widget.bookingData.selectedVehicleType != null
                                ? widget.bookingData.selectedVehicleType!
                                    .replaceAll('_', ' ')
                                    .split(' ')
                                    .map((word) => word[0].toUpperCase() + word.substring(1))
                                    .join(' ')
                                : '-'}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text('Capacity: ${widget.bookingData.capacityKg} kg', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 12),
                          Text('Distance: ${widget.bookingData.distanceKm} km', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text('Fare: ₹${widget.bookingData.totalFare}', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
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
                    final customer_id = prefs.getInt('customer');
                    widget.bookingData.description = _descriptionController.text;
                    widget.bookingData.instructions = _instructionsController.text;
                    widget.bookingData.distanceKm = widget.bookingData.distanceKm;
                    widget.bookingData.customer = customer_id?.toString();
                    widget.bookingData.boxes = int.tryParse(_boxesController.text);
                    widget.bookingData.helper_required = _helperRequired;
                    print('📦 Booking data: ${jsonEncode(widget.bookingData.toJson())}');
                    final uri = Uri.parse('http://192.168.0.105:8000/api/bookings/start/');

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