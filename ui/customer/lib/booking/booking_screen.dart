import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Timer? _locationUpdateTimer;
  final String googleApiKey = 'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II';
  final ApiService _apiService = ApiService(googleApiKey: 'AIzaSyDWbXw8OI3ihn4byK5VHyMWLnestkBm1II');
  Timer? _pollingTimer;
  bool _isArriving = false;
  int? bookingId;
  bool _isLoading = true;
  String _partnerName = '';
  String _driverPhone = '';
  String _vehicleNumber = '';
  String _vehicleType = '';
  double? _lat;
  double? _lng;
  double? _pickupLat;
  double? _pickupLng;
  BitmapDescriptor? _driverIcon;
  List<Polyline> _polylines = [];
  Set<Marker> _markers = {};
  double? _customerLat;
  double? _customerLng;
  GoogleMapController? _mapController;
  String? _pickupOtp;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (bookingId == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      bookingId = args?['id'];
      _customerLat = args?['customer_lat'];
      _customerLng = args?['customer_lng'];
      print('Booking ID received in BookingScreen: $bookingId');
      if (bookingId != null) {
        _startPolling();
      }
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchBooking());
  }

  Future<void> _fetchBooking() async {
    print('🔄 Fetching booking status for ID: $bookingId');
    final url = Uri.parse('http://192.168.0.100:8000/api/bookings/$bookingId/');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pickupOtp = data['pickup_otp'];
        print('🔐 Pickup OTP: $pickupOtp');
        _pickupOtp = data['pickup_otp']?.toString();
        if (data['status'] == 'arriving' && !_isArriving) {
          final partnerId = data['partner'];
          final pickupLatLng = data['pickup_latlng'];
          if (pickupLatLng != null) {
            final coords = pickupLatLng['coordinates'];
            if (coords != null && coords.length >= 2) {
              _pickupLng = coords[0];
              _pickupLat = coords[1];
            }
          }
          await _fetchPartnerProfile(partnerId); // fetch partner details
          if (mounted) {
            setState(() {
              _isArriving = true;
              _isLoading = false;
            });
          }
          _startLocationUpdates(partnerId);
          _pollingTimer?.cancel();
        }
      } else {
        print('Error fetching booking: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _startLocationUpdates(int partnerId) {
    _locationUpdateTimer?.cancel(); // Cancel existing timer if any
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final url = Uri.parse('http://192.168.0.100:8000/api/users/partner/location/?partner_id=$partnerId');
      try {
        final response = await http.get(url, headers: {
          'Content-Type': 'application/json',
        });
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('📍 Partner location fetched: lat=${data['latitude']}, lng=${data['longitude']}');
          setState(() {
            _lat = data['latitude'];
            _lng = data['longitude'];
          });
          if (_lat != null && _lng != null && _pickupLat != null && _pickupLng != null) {
            await _drawRoute();
          }
        } else {
          print('Location API error: ${response.statusCode}');
        }
      } catch (e) {
        print('Location fetch error: $e');
      }
    });
  }

  Future<void> _fetchPartnerProfile(int partnerId) async {
    final url = Uri.parse('http://192.168.0.100:8000/api/users/partner/profile/?id=$partnerId');
    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        print('📦 Partner profile response: ${response.body}');
        final data = json.decode(response.body);
        final properties = data['properties'];
        final geometry = data['geometry'];
        _partnerName = properties['driver_name'] ?? '';
        _driverPhone = properties['driver_phone']?.toString() ?? '';
        _vehicleNumber = properties['vehicle_number'] ?? '';
        _vehicleType = properties['vehicle_type'] ?? '';
        final coords = geometry['coordinates'];
        _lng = coords[0];
        _lat = coords[1];

        String vehicleEmoji;
        switch (_vehicleType.toLowerCase()) {
          case 'bike':
            vehicleEmoji = '🛵';
            break;
          case 'auto':
            vehicleEmoji = '🚗';
            break;
          case 'truck':
            vehicleEmoji = '🚚';
            break;
          default:
            vehicleEmoji = '🚘';
        }
        _driverIcon = await createEmojiMarker(vehicleEmoji);

        if (_lat != null && _lng != null && _pickupLat != null && _pickupLng != null) {
          await _drawRoute();
        }
        setState(() {});
      } else {
        print('Error fetching partner profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching partner profile: $e');
    }
  }

  Future<BitmapDescriptor> createEmojiMarker(String emoji) async {
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: 64),
      ),
    );
    textPainter.layout();
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    textPainter.paint(canvas, Offset.zero);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(textPainter.width.ceil(), textPainter.height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _drawRoute() async {
    if (_lat == null || _lng == null || _pickupLat == null || _pickupLng == null) return;

    final from = LatLng(_lat!, _lng!);
    final to = LatLng(_pickupLat!, _pickupLng!);
    final polylineCoordinates = await _apiService.getRoutePolyline(from, to);

    _polylines = [
      Polyline(
        polylineId: const PolylineId('driver_to_pickup'),
        color: Colors.blue,
        width: 5,
        points: polylineCoordinates,
      )
    ];

    _markers = {};
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: from,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: '$_partnerName',
          snippet: '$_vehicleType ($_vehicleNumber)',
        ),
      ),
    );

    // Custom marker for pickup location with text "Pick-up"
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: '📍 Pick-up',
        style: TextStyle(fontSize: 36, color: Colors.black),
      ),
    );
    textPainter.layout();
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    // Draw white background behind text
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, textPainter.width + 10, textPainter.height + 10),
      backgroundPaint,
    );

    // Paint the text on top
    textPainter.paint(canvas, const Offset(5, 5));

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(
      (textPainter.width + 10).ceil(),
      (textPainter.height + 10).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pickupBytes = byteData!.buffer.asUint8List();
    final pickupIcon = BitmapDescriptor.fromBytes(pickupBytes);

    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: to,
        icon: pickupIcon,
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
    );

    if (mounted) {
      final controller = _mapController;
      if (controller != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            _lat! < _pickupLat! ? _lat! : _pickupLat!,
            _lng! < _pickupLng! ? _lng! : _pickupLng!,
          ),
          northeast: LatLng(
            _lat! > _pickupLat! ? _lat! : _pickupLat!,
            _lng! > _pickupLng! ? _lng! : _pickupLng!,
          ),
        );
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _isArriving ? 'Arriving' : 'Booking In Progress',
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_lat != null && _lng != null)
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_lat!, _lng!),
                      zoom: 15,
                    ),
                    polylines: Set<Polyline>.of(_polylines),
                    markers: _markers,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Your driver $_partnerName is on the way',
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text('Phone: $_driverPhone', style: GoogleFonts.manrope()),
                          Text('Vehicle: $_vehicleType ($_vehicleNumber)', style: GoogleFonts.manrope()),
                          if (_pickupOtp != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Pickup OTP: $_pickupOtp',
                              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final cleanedPhone = _driverPhone.replaceAll(RegExp(r'[^+\d]'), '');
                              final uri = Uri(scheme: 'tel', path: cleanedPhone);

                              final canLaunch = await canLaunchUrl(uri);

                              if (canLaunch) {
                                final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not launch dialer for $cleanedPhone')),
                                );
                              }
                            },
                            icon: const Icon(Icons.phone),
                            label: Text('Contact Driver', style: GoogleFonts.manrope()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
