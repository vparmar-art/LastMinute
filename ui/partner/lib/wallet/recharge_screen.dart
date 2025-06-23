import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  List<dynamic> _plans = [];
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    final response = await http.get(Uri.parse('http://192.168.0.100:8000/api/wallet/plans/'));
    print('📥 Plan API response: ${response.body}');
    if (response.statusCode == 200) {
      setState(() {
        _plans = json.decode(response.body);
      });
    } else {
      print('❌ Failed to fetch plans: ${response.statusCode}');
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
      Uri.parse('http://192.168.0.100:8000/api/wallet/recharge/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'partner_id': partnerId,
        'plan_id': _selectedPlanId,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Recharge successful: ${response.body}');
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
      print('❌ Recharge failed: ${response.statusCode} ${response.body}');
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
      body: _plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
