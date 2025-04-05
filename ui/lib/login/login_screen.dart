import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:ui/login/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _error;
  int _resendCooldown = 0;
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _phoneController.text = 'XXXXXXXXXX';
    _phoneController.selection = TextSelection.collapsed(offset: 0);
  }

  void _sendOtp() async {
    final phone = _phoneController.text.replaceAll('X', '').trim();
    if (phone.isNotEmpty && phone.length == 10) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        await _apiService.sendOtp(phone);
        setState(() {
          _otpSent = true;
          _resendCooldown = 30;
        });
        _startCooldownTimer();
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _error = 'Enter a valid phone number';
      });
    }
  }

  void _verifyOtp() async {
    final otp = _otpController.text.trim();
    final phone = _phoneController.text.replaceAll('X', '').trim();
    if (otp.length == 4) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final token = await _apiService.verifyOtp(phone, otp);
        print('Login successful. Token: $token');

        // Save token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        // Navigate to the home screen (example)
        Navigator.pushReplacementNamed(context, '/home');

      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _error = 'Enter a valid 4-digit OTP';
      });
    }
  }

  void _startCooldownTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to LastMinute 🚚',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 240,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      child: Row(
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '+91',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 48,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  cursorColor: Colors.black,
                                  enableInteractiveSelection: false,
                                  style: const TextStyle(
                                    color: Colors.transparent,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Courier',
                                    letterSpacing: 1.6,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    border: InputBorder.none,
                                    counterText: '',
                                  ),
                                  onChanged: (value) {
                                    final raw = value.replaceAll('X', '');
                                    if (raw.length <= 10) {
                                      final masked = raw + 'X' * (10 - raw.length);
                                      final cursorPos = raw.length;
                                      _phoneController.value = TextEditingValue(
                                        text: masked,
                                        selection: TextSelection.collapsed(offset: cursorPos),
                                      );
                                    }
                                    if (_error != null) setState(() => _error = null);
                                  },
                                ),
                                IgnorePointer(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: AnimatedBuilder(
                                      animation: _phoneController,
                                      builder: (context, _) {
                                        final input = _phoneController.text.replaceAll('X', '');
                                        final remaining = 10 - input.length;
                                        return RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: input,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Courier',
                                                  letterSpacing: 1.6,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'X' * remaining,
                                                style: TextStyle(
                                                  color: Colors.grey[300],
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Courier',
                                                  letterSpacing: 1.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter OTP',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          counterText: '',
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    width: 240,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff1e88e5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _otpSent ? 'Verify OTP' : 'Send OTP',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  if (_otpSent && _resendCooldown > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('Resend OTP in $_resendCooldown seconds'),
                    ),
                  if (_otpSent && _resendCooldown == 0)
                    TextButton(
                      onPressed: _sendOtp,
                      child: const Text('Resend OTP'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
