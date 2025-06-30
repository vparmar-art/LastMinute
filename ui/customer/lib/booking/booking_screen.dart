import '../constants.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:web_socket_channel/web_socket_channel.dart';
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
  // Timer? _pollingTimer;
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
  double? _dropLat;
  double? _dropLng;
  BitmapDescriptor? _driverIcon;
  List<Polyline> _polylines = [];
  Set<Marker> _markers = {};
  double? _customerLat;
  double? _customerLng;
  GoogleMapController? _mapController;
  String? _pickupOtp;
  String? _dropOtp;
  WebSocketChannel? _channel;

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
      if (bookingId != null) {
        _startBookingWebSocket();
      }
    }
  }

  // void _startPolling() {
  //   _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchBooking());
  // }

  void _startBookingWebSocket() {
    if (bookingId == null) return;
    final wsUrl = Uri.parse('$wsBaseUrl/bookings/$bookingId/');
    _channel = WebSocketChannel.connect(wsUrl);
    final channel = _channel!;

    channel.stream.listen((message) async {
      try {
        final data = jsonDecode(message);

        // --- Begin logic from _fetchBooking for parsing and state ---
        // Parse pickup_otp, drop_otp, partner_details, pickup_latlng, drop_latlng, geometry, status
        final partner = data['partner_details'];
        final partnerProperties = partner?['properties'];
        final pickupLatLng = data['pickup_latlng'];
        final dropLatLng = data['drop_latlng'];
        final geometry = partner?['geometry'];
        final status = data['status'];

        _pickupOtp = data['pickup_otp']?.toString();
        _dropOtp = data['drop_otp']?.toString();
        _partnerName = partnerProperties != null && partnerProperties['driver_name'] != null ? partnerProperties['driver_name'] : '';
        _driverPhone = partnerProperties != null && partnerProperties['driver_phone'] != null ? partnerProperties['driver_phone'].toString() : '';
        _vehicleNumber = partnerProperties != null && partnerProperties['vehicle_number'] != null ? partnerProperties['vehicle_number'] : '';
        _vehicleType = partnerProperties != null && partnerProperties['vehicle_type'] != null ? partnerProperties['vehicle_type'] : '';

        // Parse pickupLatLng using 'coordinates' if present
        if (pickupLatLng != null && pickupLatLng['coordinates'] != null) {
          final coords = pickupLatLng['coordinates'];
          _pickupLng = coords[0];
          _pickupLat = coords[1];
        }
        // Parse dropLatLng using 'coordinates' if present
        if (dropLatLng != null && dropLatLng['coordinates'] != null) {
          final coords = dropLatLng['coordinates'];
          _dropLng = coords[0];
          _dropLat = coords[1];
        }
        // Parse geometry using 'coordinates'
        if (geometry != null && geometry['coordinates'] != null) {
          final coords = geometry['coordinates'];
          _lng = coords[0];
          _lat = coords[1];
        }

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

        // Only call _drawRoute/_drawDropRoute after _driverIcon is initialized
        if (_driverIcon != null) {
          if (status == 'arriving') {
            if (mounted) {
              setState(() {
                _isArriving = true;
                _isLoading = false;
              });
            }
            if (_lat != null && _lng != null && _pickupLat != null && _pickupLng != null) {
              await _drawRoute();
            }
          } else if (status == 'in_transit') {
            print('🚗 Ride is ongoing');
            if (mounted) {
              setState(() {
                _isArriving = false;
                _isLoading = false;
              });
            }
            if (_lat != null && _lng != null && _dropLat != null && _dropLng != null) {
              await _drawDropRoute();
            }
          } else if (status == 'completed') {
            print('✅ Ride completed, navigating to home');
            _channel?.sink.close();
            _channel = null;
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            }
          }
        }
        // --- End logic from _fetchBooking ---
      } catch (e) {
        print('❌ Error decoding Booking WebSocket message: $e');
      }
    }, onError: (error) {
      print('❌ Booking WebSocket error for bookingId $bookingId: $error');
    }, onDone: () {
      print('🔌 Booking WebSocket connection done for bookingId: $bookingId');
      // Attempt reconnection
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          print('🔄 Retrying WebSocket connection...');
          _startBookingWebSocket();
        }
      });
    });
  }

  // _fetchBooking method removed; logic now handled in _startBookingWebSocket

  // Uncommented and replaced by _startBookingWebSocket()


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
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 150));
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _drawDropRoute() async {
    if (_lat == null || _lng == null || _dropLat == null || _dropLng == null) return;

    final from = LatLng(_lat!, _lng!);
    final to = LatLng(_dropLat!, _dropLng!);
    final polylineCoordinates = await _apiService.getRoutePolyline(from, to);

    _polylines = [
      Polyline(
        polylineId: const PolylineId('driver_to_drop'),
        color: Colors.green,
        width: 5,
        points: polylineCoordinates,
      )
    ];

    _markers = {
      Marker(
        markerId: const MarkerId('driver'),
        position: from,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
      ),
      Marker(
        markerId: const MarkerId('drop'),
        position: to,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop Location'),
      ),
    };

    if (mounted && _mapController != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _lat! < _dropLat! ? _lat! : _dropLat!,
          _lng! < _dropLng! ? _lng! : _dropLng!,
        ),
        northeast: LatLng(
          _lat! > _dropLat! ? _lat! : _dropLat!,
          _lng! > _dropLng! ? _lng! : _dropLng!,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 150));
    }

    setState(() {});
  }

  @override
  void dispose() {
    // _pollingTimer?.cancel();
    _locationUpdateTimer?.cancel();
    // Do not close the WebSocket here; only close on ride completed
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
          _isArriving ? 'Arriving' : (_pickupOtp == null ? 'Booking In Progress' : 'Ride In Progress'),
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
                            _isArriving
                                ? 'Your driver $_partnerName is on the way'
                                : 'Ride in progress with $_partnerName',
                            style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text('Phone: $_driverPhone', style: GoogleFonts.manrope()),
                          Text('Vehicle: $_vehicleType ($_vehicleNumber)', style: GoogleFonts.manrope()),
                          if (_pickupOtp != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _isArriving ? 'Pickup OTP: $_pickupOtp' : 'Drop OTP: $_dropOtp',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                          if (_isArriving) ...[
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
                          ]
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
