import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Marker? _fromMarker;
  Marker? _toMarker;
  List<Polyline> _polylines = [];

  LatLng? _fromLatLng;
  LatLng? _toLatLng;

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];

  late places_sdk.FlutterGooglePlacesSdk _places;

  String? _token;
  final String googleApiKey = 'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II';

  @override
  void initState() {
    super.initState();
    _places = places_sdk.FlutterGooglePlacesSdk(googleApiKey);
    _loadToken();
    _determinePosition();

    _fromController.addListener(() {
      if (_fromController.text.isNotEmpty) {
        setState(() {
          _fromLatLng = null;
          _fromMarker = null;
        });
      }
    });

    _toController.addListener(() {
      if (_toController.text.isNotEmpty) {
        setState(() {
          _toLatLng = null;
          _toMarker = null;
        });
      }
    });
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

    final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      final place = placemarks.first;
      _fromController.text = "${place.name}, ${place.locality}, ${place.administrativeArea}";
    }

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
      FocusScope.of(context).unfocus();
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

        final marker = Marker(
          markerId: MarkerId(suggestion),
          position: latLng,
          infoWindow: InfoWindow(title: suggestion),
        );

        setState(() {
          if (isFrom) {
            _fromLatLng = latLng;
            _fromMarker = marker;
          } else {
            _toLatLng = latLng;
            _toMarker = marker;
          }
        });
      }
    }

    _polylines.clear();
  }

  Future<void> _drawRoute() async {
    if (_fromLatLng == null || _toLatLng == null) return;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_fromLatLng!.latitude},${_fromLatLng!.longitude}&destination=${_toLatLng!.latitude},${_toLatLng!.longitude}&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['routes'].isEmpty) return;

    final points = PolylinePoints().decodePolyline(
      data['routes'][0]['overview_polyline']['points'],
    );

    final route = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final polyline = Polyline(
      polylineId: const PolylineId("route"),
      color: Colors.blue,
      width: 5,
      points: route,
    );

    setState(() {
      _polylines = [polyline];
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            _fromLatLng!.latitude < _toLatLng!.latitude ? _fromLatLng!.latitude : _toLatLng!.latitude,
            _fromLatLng!.longitude < _toLatLng!.longitude ? _fromLatLng!.longitude : _toLatLng!.longitude,
          ),
          northeast: LatLng(
            _fromLatLng!.latitude > _toLatLng!.latitude ? _fromLatLng!.latitude : _toLatLng!.latitude,
            _fromLatLng!.longitude > _toLatLng!.longitude ? _fromLatLng!.longitude : _toLatLng!.longitude,
          ),
        ),
        100,
      ),
    );
  }

  Widget _buildCombinedSearchBox() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSearchInput(
                label: "From",
                controller: _fromController,
                focusNode: _fromFocus,
                isFrom: true,
              ),
              const Divider(height: 1),
              _buildSearchInput(
                label: "To",
                controller: _toController,
                focusNode: _toFocus,
                isFrom: false,
              ),
            ],
          ),
        ),
        _buildSuggestions(_fromSuggestions, true),
        _buildSuggestions(_toSuggestions, false),
      ],
    );
  }

  Widget _buildSearchInput({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFrom,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        ),
        onChanged: (value) => _searchPlace(value, isFrom),
      ),
    );
  }

  Widget _buildSuggestions(List<String> suggestions, bool isFrom) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }
    if (_fromMarker != null) markers.add(_fromMarker!);
    if (_toMarker != null) markers.add(_toMarker!);

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
            markers: markers,
            polylines: Set<Polyline>.of(_polylines),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: _buildCombinedSearchBox(),
          ),
          if (_fromLatLng != null && _toLatLng != null)
            Positioned(
              top: 160,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _drawRoute,
                child: const Text("Confirm"),
              ),
            ),
        ],
      ),
    );
  }
}