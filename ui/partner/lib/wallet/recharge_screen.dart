import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  List<dynamic> _plans = [];
  int? _selectedPlanId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📋 Fetching plans from: $apiBaseUrl/wallet/plans/');
      final response = await http.get(Uri.parse('$apiBaseUrl/wallet/plans/'));
      
      print('📋 Plans API response status: ${response.statusCode}');
      print('📋 Plans API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final plansData = json.decode(response.body);
        print('📋 Plans data: $plansData');
        setState(() {
          _plans = plansData is List ? plansData : [];
          _isLoading = false;
        });
        
        if (_plans.isEmpty) {
          setState(() {
            _errorMessage = 'No plans available. Please contact support.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load plans. Status: ${response.statusCode}';
        });
        print('❌ Failed to fetch plans: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading plans: $e';
      });
      print('❌ Error fetching plans: $e');
    }
  }

  void _selectPlan(int planId) {
    setState(() {
      _selectedPlanId = planId;
    });
  }

  void _pay() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PLEASE SELECT A PLAN')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final partnerId = prefs.getInt('partner_id');
    if (partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PARTNER ID NOT FOUND')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('$apiBaseUrl/wallet/recharge/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'partner_id': partnerId,
        'plan_id': _selectedPlanId,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RECHARGE SUCCESSFUL'),
          duration: Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RECHARGE FAILED')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPlans,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
          : _plans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'No plans available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please contact support or check back later',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _plans.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      final isSelected = _selectedPlanId == plan['id'];
                      return GestureDetector(
                        onTap: () => _selectPlan(plan['id']),
                        child: Card(
                          color: isSelected ? Colors.indigo.shade100 : Colors.white,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: isSelected ? Colors.indigo : Colors.grey.shade300, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan['name'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('₹${plan['amount']}'.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                if (plan['ride_credits'] != null)
                                  Text('${plan['ride_credits']} RIDES', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (plan['duration_days'] != null)
                                  Text('VALID FOR ${plan['duration_days']} DAYS', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (plan['description'] != null && plan['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(plan['description'].toString().toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _pay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('PAY', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
    );
  }
}
