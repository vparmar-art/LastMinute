import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
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

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];

  late places_sdk.FlutterGooglePlacesSdk _places;

  String? _token;

  @override
  void initState() {
    super.initState();
    _places = places_sdk.FlutterGooglePlacesSdk(
        'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II');
    _loadToken();
    _determinePosition();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    setState(() {
      _token = token;
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) return;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(position.latitude, position.longitude);

    _markers.add(
      Marker(
        markerId: const MarkerId('current'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
      ),
    );

    setState(() {});

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 15),
      ),
    );
  }

  void _searchPlace(String query, bool isFrom) async {
    if (query.isEmpty) {
      setState(() {
        if (isFrom) {
          _fromSuggestions = [];
        } else {
          _toSuggestions = [];
        }
      });
      return;
    }

    final result = await _places.findAutocompletePredictions(query);
    if (result.predictions.isNotEmpty) {
    final suggestions = result.predictions
        .map((p) => p.fullText ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

      setState(() {
        if (isFrom) {
          _fromSuggestions = suggestions;
        } else {
          _toSuggestions = suggestions;
        }
      });
    }
  }

  void _selectSuggestion(String suggestion, bool isFrom) async {
    if (isFrom) {
      _fromController.text = suggestion;
      _fromSuggestions.clear();
    } else {
      _toController.text = suggestion;
      _toSuggestions.clear();
    }

    final result = await _places.findAutocompletePredictions(suggestion);
    if (result.predictions.isNotEmpty) {
      final placeId = result.predictions.first.placeId;
      final place = await _places.fetchPlace(placeId,
          fields: [places_sdk.PlaceField.Location]);

      final loc = place.place?.latLng;
      if (loc != null) {
        final latLng = LatLng(loc.lat, loc.lng);

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 15),
          ),
        );

        _markers.add(
          Marker(
            markerId: MarkerId(suggestion),
            position: latLng,
            infoWindow: InfoWindow(title: suggestion),
          ),
        );

        setState(() {});
      }
    }
  }

  Widget _buildSearchBox({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFrom,
    required List<String> suggestions,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: label,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
            ),
            onChanged: (value) => _searchPlace(value, isFrom),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: suggestions
                  .map(
                    (s) => ListTile(
                      title: Text(s),
                      onTap: () => _selectSuggestion(s, isFrom),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
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
                _buildSearchBox(
                  label: "From",
                  controller: _fromController,
                  focusNode: _fromFocus,
                  isFrom: true,
                  suggestions: _fromSuggestions,
                ),
                const SizedBox(height: 10),
                _buildSearchBox(
                  label: "To",
                  controller: _toController,
                  focusNode: _toFocus,
                  isFrom: false,
                  suggestions: _toSuggestions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}