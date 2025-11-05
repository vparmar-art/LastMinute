import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

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

  // Scheduling state
  int _selectedBookingType = 0; // 0 = Book Now, 1 = Schedule for Later
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: ToggleButtons(
                        isSelected: [_selectedBookingType == 0, _selectedBookingType == 1],
                        onPressed: (index) {
                          setState(() {
                            _selectedBookingType = index;
                            if (index == 0) {
                              _scheduledDate = null;
                              _scheduledTime = null;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: AppColors.accent,
                        color: Colors.grey[400],
                        constraints: const BoxConstraints(minWidth: 140, minHeight: 40),
                        children: const [
                          Text('Book Now', style: TextStyle(fontSize: 16)),
                          Text('Schedule', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedBookingType == 1) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text(_scheduledDate == null
                          ? 'Select Date'
                          : 'Date: 	${_scheduledDate!.toLocal().toString().split(' ')[0]}'),
                      leading: const Icon(Icons.calendar_today),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode()); // Unfocus any text field
                        await Future.delayed(const Duration(milliseconds: 50)); // Wait for keyboard to close
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now.add(const Duration(days: 1)),
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _scheduledDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: Text(_scheduledTime == null
                          ? 'Select Time'
                          : 'Time: ${_scheduledTime!.format(context)}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode()); // Unfocus any text field
                        await Future.delayed(const Duration(milliseconds: 50)); // Wait for keyboard to close
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => _scheduledTime = picked);
                        }
                      },
                    ),
                  ],
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
                  if (_selectedBookingType == 1 && (_scheduledDate == null || _scheduledTime == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both date and time for scheduling.')),
                    );
                    return;
                  }
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

                    // Prepare payload
                    final payload = widget.bookingData.toJson();
                    if (_selectedBookingType == 1) {
                      final dt = DateTime(
                        _scheduledDate!.year,
                        _scheduledDate!.month,
                        _scheduledDate!.day,
                        _scheduledTime!.hour,
                        _scheduledTime!.minute,
                      );
                      payload['booking_type'] = 'scheduled';
                      payload['scheduled_time'] = dt.toIso8601String();
                    } else {
                      payload['booking_type'] = 'immediate';
                    }

                    final uri = Uri.parse('$apiBaseUrl/bookings/start/');
                    final response = await http.post(
                      uri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode(payload),
                    );

                    if (response.statusCode == 201) {
                      final responseData = jsonDecode(response.body);
                      final bookingId = responseData['id'];
                      if (_selectedBookingType == 1) {
                        // Show dialog for scheduled bookings
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Booking Scheduled!'),
                            content: const Text('Your ride has been scheduled successfully.'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog
                                  Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false); // Go to home
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Existing flow for immediate bookings
                        Navigator.pushReplacementNamed(
                          context,
                          '/booking',
                          arguments: {'id': bookingId},
                        );
                      }
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
                backgroundColor: AppColors.accent,
              ),
              child: Text('Book', style: AppTextStyles.buttonText),
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