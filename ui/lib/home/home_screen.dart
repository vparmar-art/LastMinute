import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'api_service.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _googleApiKey = 'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II';
  late final ApiService _apiService;

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];

  bool _isValidSelection = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(googleApiKey: _googleApiKey);
    _loadToken();
    _determinePosition();

    _fromController.addListener(_onInputChanged);
    _toController.addListener(_onInputChanged);

    _fromFocus.addListener(() {
      if (!_fromFocus.hasFocus) {
        setState(() => _fromSuggestions.clear());
      }
    });
    _toFocus.addListener(() {
      if (!_toFocus.hasFocus) {
        setState(() => _toSuggestions.clear());
      }
    });
  }

  void _onInputChanged() {
    setState(() {
      _isValidSelection =
          _fromController.text.isNotEmpty && _toController.text.isNotEmpty;
    });
  }

  Future<void> _loadToken() async {
    final token = await _apiService.getToken();
    if (token == null) {
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
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

    final address =
        await _apiService.getAddressFromCoordinates(_currentLocation!);
    if (address != null) {
      _fromController.text = address;
      _addMarker(_currentLocation!, 'from', address);
    }

    setState(() {});
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 15),
      ),
    );
  }

  void _searchPlace(String query, bool isFrom) async {
    final suggestions = await _apiService.searchPlace(query);
    setState(() {
      if (isFrom) {
        _fromSuggestions = suggestions;
      } else {
        _toSuggestions = suggestions;
      }
    });
  }

  void _addMarker(LatLng position, String id, String title) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == id);
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: position,
          infoWindow: InfoWindow(title: title),
        ),
      );
    });
  }

  void _selectSuggestion(String suggestion, bool isFrom) async {
    final latLng = await _apiService.getLatLngFromSuggestion(suggestion);
    if (latLng == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15),
      ),
    );

    _addMarker(latLng, isFrom ? 'from' : 'to', suggestion);

    setState(() {
      if (isFrom) {
        _fromController.text = suggestion;
        _fromSuggestions.clear();
      } else {
        _toController.text = suggestion;
        _toSuggestions.clear();
      }
      _isValidSelection =
          _fromController.text.isNotEmpty && _toController.text.isNotEmpty;
    });
  }

  Future<void> _drawRoute() async {
    final fromLatLng =
        await _apiService.getLatLngFromSuggestion(_fromController.text);
    final toLatLng =
        await _apiService.getLatLngFromSuggestion(_toController.text);
    if (fromLatLng == null || toLatLng == null) return;

    _addMarker(fromLatLng, 'from', _fromController.text);
    _addMarker(toLatLng, 'to', _toController.text);

    final route = await _apiService.getRoutePolyline(fromLatLng, toLatLng);

    setState(() {
      _polylines = [
        Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.blue,
          width: 5,
          points: route,
        ),
      ];
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            fromLatLng.latitude < toLatLng.latitude
                ? fromLatLng.latitude
                : toLatLng.latitude,
            fromLatLng.longitude < toLatLng.longitude
                ? fromLatLng.longitude
                : toLatLng.longitude,
          ),
          northeast: LatLng(
            fromLatLng.latitude > toLatLng.latitude
                ? fromLatLng.latitude
                : toLatLng.latitude,
            fromLatLng.longitude > toLatLng.longitude
                ? fromLatLng.longitude
                : toLatLng.longitude,
          ),
        ),
        100,
      ),
    );
  }

  Widget _buildSearchInput(String label, TextEditingController controller,
      FocusNode focusNode, bool isFrom) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: label,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: suggestions
            .map((s) => ListTile(
                title: Text(s), onTap: () => _selectSuggestion(s, isFrom)))
            .toList(),
      ),
    );
  }

  Widget _buildCombinedSearchBox() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              _buildSearchInput("From", _fromController, _fromFocus, true),
              const Divider(height: 1),
              _buildSearchInput("To", _toController, _toFocus, false),
              if (_isValidSelection)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: ElevatedButton(
                    onPressed: _drawRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: const Text("Confirm"),
                  ),
                ),
            ],
          ),
        ),
        _buildSuggestions(_fromSuggestions, true),
        _buildSuggestions(_toSuggestions, false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Home', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
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
            polylines: Set<Polyline>.of(_polylines),
          ),
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: _buildCombinedSearchBox(),
          ),
        ],
      ),
    );
  }
}