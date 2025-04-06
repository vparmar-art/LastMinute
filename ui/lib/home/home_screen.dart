import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  List<Marker> _markers = [];

  TextEditingController _fromController = TextEditingController();
  TextEditingController _toController = TextEditingController();

  String? _token;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _determinePosition();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    print('Stored token: $token');

    setState(() {
      _token = token;
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error('Location permissions are denied.');
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _markers.add(
        Marker(
          markerId: MarkerId('current'),
          position: _currentLocation!,
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      );
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 15),
        ),
      );
    }
  }

  Widget _buildSearchField(String label, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
        ),
        onTap: () {
          // TODO: Launch Google Place Autocomplete
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Home',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(28.6139, 77.2090),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentLocation!, zoom: 15),
                  ),
                );
              }
            },
            markers: Set<Marker>.of(_markers),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                _buildSearchField("Pickup location", _fromController),
                const SizedBox(height: 10),
                _buildSearchField("Drop location", _toController),
              ],
            ),
          ),
        ],
      ),
    );
  }
}