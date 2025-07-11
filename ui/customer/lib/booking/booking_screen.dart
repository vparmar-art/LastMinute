import '../constants.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import '../utils/ride_state_manager.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with WidgetsBindingObserver {
  Timer? _locationUpdateTimer;
  final String googleApiKey = 'AIzaSyDktJbUpou1FhxfYCaaYywC-145hPE7qb0';
  final ApiService _apiService = ApiService(googleApiKey: 'AIzaSyDktJbUpou1FhxfYCaaYywC-145hPE7qb0');
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
  bool _isAppActive = true;
  bool _isConnecting = false;
  
  // Enhanced ride experience variables
  String _eta = '';
  String _distance = '';
  String _rideStatus = 'Looking for driver...';
  bool _showEmergencyButton = false;
  bool _isRideCompleted = false;
  double _rideProgress = 0.0;
  Timer? _etaUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (bookingId == null) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      bookingId = args?['id'];
      _customerLat = args?['customer_lat'];
      _customerLng = args?['customer_lng'];
      
      // If no booking ID from arguments, try to get it from ride state
      if (bookingId == null) {
        _getBookingIdFromRideState();
      } else {
        // Restore ride state if available
        _restoreRideState();
        
        if (bookingId != null && _channel == null) {
          _startBookingWebSocket();
        }
      }
    }
  }

  Future<void> _getBookingIdFromRideState() async {
    final rideState = await RideStateManager.getRideState();
    if (rideState != null && rideState.isActive) {
      setState(() {
        bookingId = rideState.bookingId;
      });
      
      // Restore ride state and start WebSocket
      await _restoreRideState();
      
      if (bookingId != null && _channel == null) {
        _startBookingWebSocket();
      }
    }
  }

  Future<void> _restoreRideState() async {
    final rideState = await RideStateManager.getRideState();
    if (rideState != null && rideState.isActive) {
      // If bookingId is null, use the one from ride state
      if (bookingId == null) {
        bookingId = rideState.bookingId;
      }
      
      // Only restore if the booking IDs match or if we don't have a booking ID yet
      if (bookingId == null || rideState.bookingId == bookingId) {
        // Restore the ride state
        setState(() {
          _partnerName = rideState.driverName ?? '';
          _driverPhone = rideState.driverPhone ?? '';
          _vehicleNumber = rideState.vehicleNumber ?? '';
          _vehicleType = rideState.vehicleType ?? '';
          _pickupOtp = rideState.pickupOtp;
          _dropOtp = rideState.dropOtp;
          
          // Set appropriate status based on ride state
          if (rideState.status == 'arriving') {
            _isArriving = true;
            _isLoading = false;
            _rideStatus = 'Driver is arriving...';
            _showEmergencyButton = true;
          } else if (rideState.status == 'in_transit') {
            _isArriving = false;
            _isLoading = false;
            _rideStatus = 'Ride in progress...';
            _showEmergencyButton = true;
          } else if (rideState.status == 'created') {
            _isLoading = true;
            _rideStatus = 'Looking for driver...';
          }
        });
        
        // If we have driver info, create the vehicle icon
        if (_vehicleType.isNotEmpty) {
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
        }
      }
    }
  }

  void _startBookingWebSocket() {
    if (bookingId == null || _channel != null || _isConnecting || !_isAppActive) {
      return;
    }
    _isConnecting = true;
    try {
      final wsUrl = Uri.parse('$wsBaseUrl/bookings/$bookingId/');
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnecting = false;
      final channel = _channel!;
      channel.stream.listen((message) async {
                  try {
            final data = jsonDecode(message);
            final partner = data['partner_details'];
            final partnerProperties = partner?['properties'];
            final pickupLatLng = data['pickup_latlng'];
            final dropLatLng = data['drop_latlng'];
            final geometry = partner?['geometry'];
            final status = data['status'];
            
            if (status == 'created' && partner == null) {
              return;
            }

            _pickupOtp = data['pickup_otp']?.toString();
            _dropOtp = data['drop_otp']?.toString();
            _partnerName = partnerProperties != null && partnerProperties['driver_name'] != null ? partnerProperties['driver_name'] : '';
            _driverPhone = partnerProperties != null && partnerProperties['driver_phone'] != null ? partnerProperties['driver_phone'].toString() : '';
            _vehicleNumber = partnerProperties != null && partnerProperties['vehicle_number'] != null ? partnerProperties['vehicle_number'] : '';
            _vehicleType = partnerProperties != null && partnerProperties['vehicle_type'] != null ? partnerProperties['vehicle_type'] : '';

            // Save ride state for app resilience
            final rideState = RideState(
              bookingId: bookingId,
              status: status,
              driverName: _partnerName,
              vehicleType: _vehicleType,
              vehicleNumber: _vehicleNumber,
              driverPhone: _driverPhone,
              pickupOtp: _pickupOtp,
              dropOtp: _dropOtp,
              lastUpdated: DateTime.now(),
            );
            await RideStateManager.saveRideState(rideState);

          if (pickupLatLng != null && pickupLatLng['coordinates'] != null) {
            final coords = pickupLatLng['coordinates'];
            _pickupLng = coords[0];
            _pickupLat = coords[1];
          }
          if (dropLatLng != null && dropLatLng['coordinates'] != null) {
            final coords = dropLatLng['coordinates'];
            _dropLng = coords[0];
            _dropLat = coords[1];
          }
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

          if (_driverIcon != null) {
            if (status == 'arriving') {
              if (mounted) {
                setState(() {
                  _isArriving = true;
                  _isLoading = false;
                  _rideStatus = 'Driver is arriving';
                  _showEmergencyButton = true;
                });
              }
              if (_lat != null && _lng != null && _pickupLat != null && _pickupLng != null) {
                await _drawRoute();
                _startEtaUpdates();
              }
            } else if (status == 'in_transit') {
              if (mounted) {
                setState(() {
                  _isArriving = false;
                  _isLoading = false;
                  _rideStatus = 'Ride in progress';
                  _showEmergencyButton = true;
                });
              }
              if (_lat != null && _lng != null && _dropLat != null && _dropLng != null) {
                await _drawDropRoute();
                _startEtaUpdates();
              }
                          } else if (status == 'completed') {
                _channel?.sink.close();
                _channel = null;
                _etaUpdateTimer?.cancel();
                if (mounted) {
                  setState(() {
                    _isRideCompleted = true;
                    _rideStatus = 'Ride completed!';
                    _showEmergencyButton = false;
                  });
                  _showRideCompletionDialog();
                }
                
                // Update ride state to completed
                await RideStateManager.updateRideStatus('completed');
              }
          }
        } catch (e) {
          // Swallow error
        }
      }, onError: (error) {
        _isConnecting = false;
        _channel = null;
        if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
          Future.delayed(const Duration(seconds: 5), () {
            if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
              _startBookingWebSocket();
            }
          });
        }
      }, onDone: () {
        _isConnecting = false;
        _channel = null;
        if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
          Future.delayed(const Duration(seconds: 2), () {
            if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
              _startBookingWebSocket();
            }
          });
        }
      });
    } catch (e) {
      _isConnecting = false;
      _channel = null;
      if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_isAppActive && mounted && ModalRoute.of(context)?.isCurrent == true) {
            _startBookingWebSocket();
          }
        });
      }
    }
  }

  void _startEtaUpdates() {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_lat != null && _lng != null) {
        _updateEtaAndDistance();
      }
    });
    _updateEtaAndDistance(); // Initial update
  }

  Future<void> _updateEtaAndDistance() async {
    if (_lat == null || _lng == null) return;
    
    try {
      final targetLat = _isArriving ? _pickupLat : _dropLat;
      final targetLng = _isArriving ? _pickupLng : _dropLng;
      
      if (targetLat == null || targetLng == null) return;
      
      final url = "https://maps.googleapis.com/maps/api/distancematrix/json?origins=${_lat},${_lng}&destinations=$targetLat,$targetLng&key=$googleApiKey";
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      
      if (data['rows'] != null && data['rows'].isNotEmpty && 
          data['rows'][0]['elements'] != null && 
          data['rows'][0]['elements'].isNotEmpty) {
        final element = data['rows'][0]['elements'][0];
        if (element['status'] == 'OK') {
          final duration = element['duration']['text'];
          final distance = element['distance']['text'];
          
          if (mounted) {
            setState(() {
              _eta = duration;
              _distance = distance;
            });
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showRideCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ride Completed! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 50),
            const SizedBox(height: 16),
            Text('Thank you for choosing LastMinute!'),
            const SizedBox(height: 8),
            Text('Driver: $_partnerName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Vehicle: $_vehicleType ($_vehicleNumber)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (bookingId != null) {
                Navigator.of(context).pushNamed(
                  '/rating',
                  arguments: {
                    'bookingId': bookingId,
                    'driverName': _partnerName,
                    'vehicleType': _vehicleType,
                    'vehicleNumber': _vehicleNumber,
                  },
                );
              }
            },
            child: const Text('Rate Your Ride'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.red),
              title: const Text('Call Emergency Services'),
              subtitle: const Text('Police, Ambulance, Fire'),
              onTap: () {
                Navigator.pop(context);
                _callEmergencyServices();
              },
            ),
            ListTile(
              leading: const Icon(Icons.support_agent, color: Colors.orange),
              title: const Text('Contact Support'),
              subtitle: const Text('24/7 Customer Support'),
              onTap: () {
                Navigator.pop(context);
                _contactSupport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_location, color: Colors.blue),
              title: const Text('Share Location'),
              subtitle: const Text('Share your current location'),
              onTap: () {
                Navigator.pop(context);
                _shareLocation();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _callEmergencyServices() async {
    final uri = Uri(scheme: 'tel', path: '100'); // Emergency number
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _contactSupport() async {
    final uri = Uri(scheme: 'tel', path: '+91-1800-123-4567'); // Support number
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareLocation() {
    // Implement location sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location sharing feature coming soon!')),
    );
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
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _etaUpdateTimer?.cancel();
    if (_channel != null) {
      _channel?.sink.close();
      _channel = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        if (bookingId != null && _channel == null && !_isConnecting) {
          _startBookingWebSocket();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _isAppActive = false;
        if (_channel != null) {
          _channel?.sink.close();
          _channel = null;
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _isArriving ? 'Driver Arriving' : (_pickupOtp == null ? 'Finding Driver' : 'Ride in Progress'),
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_showEmergencyButton)
            IconButton(
              icon: const Icon(Icons.emergency, color: Colors.red),
              onPressed: _showEmergencyDialog,
              tooltip: 'Emergency',
            ),
        ],
      ),
      body: _isLoading
          ? (_pickupOtp == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Looking for drivers nearby...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator()))
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
                // Enhanced ride info card
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status and ETA
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _rideStatus,
                                      style: GoogleFonts.manrope(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _isArriving ? Colors.orange : Colors.green,
                                      ),
                                    ),
                                    if (_eta.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'ETA: $_eta',
                                        style: GoogleFonts.manrope(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                    if (_distance.isNotEmpty) ...[
                                      Text(
                                        'Distance: $_distance',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Driver info
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _partnerName,
                                    style: GoogleFonts.manrope(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$_vehicleType • $_vehicleNumber',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // OTP Section
                          if (_pickupOtp != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.key, color: Colors.blue[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isArriving ? 'Pickup OTP' : 'Drop OTP',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _isArriving ? _pickupOtp! : _dropOtp!,
                                          style: GoogleFonts.manrope(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final cleanedPhone = _driverPhone.replaceAll(RegExp(r'[^+\d]'), '');
                                    final uri = Uri(scheme: 'tel', path: cleanedPhone);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  icon: const Icon(Icons.phone),
                                  label: Text('Call Driver', style: GoogleFonts.manrope()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Share ride details
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sharing ride details...')),
                                    );
                                  },
                                  icon: const Icon(Icons.share),
                                  label: Text('Share', style: GoogleFonts.manrope()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[200],
                                    foregroundColor: Colors.black87,
                                    minimumSize: const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
