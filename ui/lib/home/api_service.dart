import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as places_sdk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class ApiService {
  final String googleApiKey;
  late final places_sdk.FlutterGooglePlacesSdk _places;

  ApiService({required this.googleApiKey}) {
    _places = places_sdk.FlutterGooglePlacesSdk(googleApiKey);
  }

  Future<List<String>> searchPlace(String query) async {
    if (query.isEmpty) return [];
    final predictions = await _places.findAutocompletePredictions(query);
    return predictions.predictions
        .map((p) => p.fullText ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<LatLng?> getLatLngFromSuggestion(String suggestion) async {
    final predictions = await _places.findAutocompletePredictions(suggestion);
    if (predictions.predictions.isEmpty) return null;

    final placeId = predictions.predictions.first.placeId;
    final placeDetails = await _places.fetchPlace(
      placeId,
      fields: [places_sdk.PlaceField.Location],
    );

    final loc = placeDetails.place?.latLng;
    if (loc == null) return null;
    return LatLng(loc.lat, loc.lng);
  }

  Future<List<LatLng>> getRoutePolyline(LatLng from, LatLng to) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${from.latitude},${from.longitude}&destination=${to.latitude},${to.longitude}&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data['routes'].isEmpty) return [];

    final points = PolylinePoints().decodePolyline(
      data['routes'][0]['overview_polyline']['points'],
    );
    return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<String?> getAddressFromCoordinates(LatLng coords) async {
    final placemarks = await placemarkFromCoordinates(coords.latitude, coords.longitude);
    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    return "${place.name}, ${place.locality}, ${place.administrativeArea}";
  }
}