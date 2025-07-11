import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class RatingScreen extends StatefulWidget {
  final int bookingId;
  final String driverName;
  final String vehicleType;
  final String vehicleNumber;

  const RatingScreen({
    Key? key,
    required this.bookingId,
    required this.driverName,
    required this.vehicleType,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/bookings/${widget.bookingId}/rate/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'rating': _rating,
          'review': _reviewController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your feedback!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to submit rating'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rate Your Ride',
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.person, size: 50, color: Colors.blue),
                  const SizedBox(height: 12),
                  Text(
                    widget.driverName,
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.vehicleType} • ${widget.vehicleNumber}',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Rating section
            Text(
              'How was your ride?',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 40,
                      color: index < _rating ? Colors.orange : Colors.grey[400],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            
            // Rating text
            Center(
              child: Text(
                _getRatingText(_rating),
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Review section
            Text(
              'Tell us more (optional)',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                hintStyle: GoogleFonts.manrope(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: GoogleFonts.manrope(),
            ),
            const SizedBox(height: 40),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Submit Rating',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Skip button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                      },
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Tap to rate';
    }
  }
} 