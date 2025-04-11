import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VehicleType {
  final String name;
  final String imageUrl;
  final double baseFare;
  final double farePerKm;
  final int capacity;

  VehicleType({
    required this.name,
    required this.imageUrl,
    required this.baseFare,
    required this.farePerKm,
    required this.capacity,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      name: json['name'],
      imageUrl: json['image'] ?? '',
      baseFare: double.parse(json['base_fare'].toString()),
      farePerKm: double.parse(json['fare_per_km'].toString()),
      capacity: json['capacity_in_kg'],
    );
  }
}

class VehiclesPart extends StatefulWidget {
  const VehiclesPart({super.key});

  @override
  State<VehiclesPart> createState() => _VehiclesPartState();
}

class _VehiclesPartState extends State<VehiclesPart> {
  List<VehicleType> vehicleTypes = [];
  bool isLoading = true;
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchVehicleTypes();
  }

  Future<void> fetchVehicleTypes() async {
    final response = await http.get(
      Uri.parse('http://192.168.29.86:8000/api/vehicles/types/'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        vehicleTypes = data.map((v) => VehicleType.fromJson(v)).toList();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _getVehicleIcon(String name) {
    IconData icon;

    if (name.toLowerCase().contains('bike')) {
      icon = Icons.delivery_dining; // delivery bike
    } else if (name.toLowerCase().contains('auto')) {
      icon = Icons.local_taxi; // cargo-friendly 3-wheeler
    } else if (name.toLowerCase().contains('mini')) {
      icon = Icons.local_shipping; // mini truck
    } else if (name.toLowerCase().contains('truck')) {
      icon = Icons.fire_truck; // larger delivery vehicle
    } else {
      icon = Icons.inventory_2; // fallback: delivery box/package
    }

    return Icon(icon, size: 28, color: Colors.deepOrangeAccent);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: vehicleTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final vehicle = vehicleTypes[index];
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedIndex = index;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: vehicle.imageUrl.isNotEmpty
                            ? Image.network(
                                vehicle.imageUrl,
                                height: 56,
                                width: 56,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 56,
                                width: 56,
                                color: Colors.orange.shade100,
                                child: Center(child: _getVehicleIcon(vehicle.name)),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "₹${vehicle.baseFare.toStringAsFixed(0)} base + ₹${vehicle.farePerKm}/km",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${vehicle.capacity} KG capacity",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add your "Add Details" logic here
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Add Details'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}