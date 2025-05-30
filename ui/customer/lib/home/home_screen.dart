import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'api_service.dart';
import 'widgets/vehicles_part.dart' show VehiclesPart, BookingData;
import 'dart:async';

class BookingData {
  String? pickupAddress;
  LatLng? pickupLatLng;
  String? dropAddress;
  LatLng? dropLatLng;
  String? selectedVehicleType;
  String? description;
  String? weight;
  String? dimensions;
  String? instructions;
  double? distanceKm;
  String? customer;
  int? totalFare;

  Map<String, dynamic> toJson() {
    return {
      'pickup_address': pickupAddress,
      'pickup_latlng': pickupLatLng != null
          ? {'lat': pickupLatLng!.latitude, 'lng': pickupLatLng!.longitude}
          : null,
      'drop_address': dropAddress,
      'drop_latlng': dropLatLng != null
          ? {'lat': dropLatLng!.latitude, 'lng': dropLatLng!.longitude}
          : null,
      'vehicle_type': selectedVehicleType,
      'description': description,
      'weight': weight,
      'dimensions': dimensions,
      'instructions': instructions,
      'distance_km': distanceKm,
      'customer': customer,
      'totalFare': totalFare
    };
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _googleApiKey = 'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II';
  late final ApiService _apiService;
  final BookingData _bookingData = BookingData();

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

  bool _isFromSelected = false;
  bool _isToSelected = false;
  bool _suppressSuggestions = false;
  bool _isConfirmed = false;
  Timer? _debounce;
  double _vehiclePanelHeight = 250.0;

  double? _calculatedDistanceKm;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(googleApiKey: _googleApiKey);
    _loadToken();
    _determinePosition();

    _fromController.addListener(() {
      if (_suppressSuggestions || _isConfirmed) return;
      if (_fromFocus.hasFocus) {
        setState(() => _isFromSelected = false);

        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          _searchPlace(_fromController.text, true);
        });
      }
    });

    _toController.addListener(() {
      if (_suppressSuggestions || _isConfirmed) return;
      if (_toFocus.hasFocus) {
        setState(() => _isToSelected = false);

        if (_debounce?.isActive ?? false) _debounce!.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), () {
          _searchPlace(_toController.text, false);
        });
      }
    });

    _fromFocus.addListener(() {
      if (!_fromFocus.hasFocus) setState(() => _fromSuggestions.clear());
    });

    _toFocus.addListener(() {
      if (!_toFocus.hasFocus) setState(() => _toSuggestions.clear());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await _apiService.getToken();
    if (token == null && mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
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
      _bookingData.pickupAddress = address;
      _bookingData.pickupLatLng = _currentLocation;
      _addMarker(_currentLocation!, 'from', address);
      _isFromSelected = true;
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
    _suppressSuggestions = true;

    final latLng = await _apiService.getLatLngFromSuggestion(suggestion);
    if (latLng == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 15),
      ),
    );

    _addMarker(latLng, isFrom ? 'from' : 'to', suggestion);

    if (isFrom) {
      _fromFocus.unfocus();
      setState(() {
        _fromSuggestions.clear();
        _fromController.text = suggestion;
        _isFromSelected = true;
      });
      _bookingData.pickupAddress = suggestion;
      _bookingData.pickupLatLng = latLng;
    } else {
      _toFocus.unfocus();
      setState(() {
        _toSuggestions.clear();
        _toController.text = suggestion;
        _isToSelected = true;
      });
      _bookingData.dropAddress = suggestion;
      _bookingData.dropLatLng = latLng;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _suppressSuggestions = false;
    });
  }

  Future<void> _drawRoute() async {
    _fromFocus.unfocus();
    _toFocus.unfocus();

    final fromLatLng = _bookingData.pickupLatLng;
    final toLatLng =
        await _apiService.getLatLngFromSuggestion(_toController.text);
    if (fromLatLng == null || toLatLng == null) return;

    final distanceInMeters = Geolocator.distanceBetween(
      fromLatLng.latitude,
      fromLatLng.longitude,
      toLatLng.latitude,
      toLatLng.longitude,
    );
    _calculatedDistanceKm = double.parse((distanceInMeters / 1000).toStringAsFixed(2));
    _bookingData.distanceKm = _calculatedDistanceKm;

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
      _isConfirmed = true;
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
    FocusNode focusNode, bool isFrom, double height) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: _isConfirmed,
          style: GoogleFonts.manrope(fontSize: 14),
          decoration: InputDecoration(
            hintText: label,
            prefixIcon: const Icon(Icons.search, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(List<String> suggestions, bool isFrom) {
    if (suggestions.isEmpty || _isConfirmed) return const SizedBox.shrink();
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
    final bool showConfirm = _isFromSelected && _isToSelected && !_isConfirmed;

    if (_isConfirmed) return const SizedBox.shrink();

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
              _buildSearchInput("From", _fromController, _fromFocus, true, _isConfirmed ? 36 : 48),
              _buildSearchInput("To", _toController, _toFocus, false, _isConfirmed ? 36 : 48),
              if (showConfirm)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        leading: _isConfirmed
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isConfirmed = false;
                    _polylines.clear();
                  });
                },
              )
            : null,
        title: Text('Home', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
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
            top: 0,
            left: 0,
            right: 0,
            child: _buildCombinedSearchBox(),
          ),
          if (_isConfirmed)
            Positioned.fill(
              child: DraggableScrollableSheet(
                initialChildSize: 0.25,
                minChildSize: 0.2,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
                      ],
                    ),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        VehiclesPart(
                          distanceKm: _calculatedDistanceKm ?? 0,
                          bookingData: _bookingData,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}