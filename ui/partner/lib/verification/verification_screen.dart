import 'package:flutter/material.dart';
import 'verification_controller.dart';

class VerificationScreen extends StatelessWidget {
  final bool isRejected;
  final String? rejectionReason;

  const VerificationScreen({
    Key? key,
    required this.isRejected,
    this.rejectionReason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = VerificationController();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verification',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  isRejected ? 'Documents Rejected' : 'Verification In-Progress',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRejected
                  ? (rejectionReason ?? 'Document verification failed.')
                  : 'You have successfully completed all verification steps. Your account is now under review.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (isRejected)
                ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () async {
                      bool success = await controller.resubmitVerification();
                      if (success) {
                        Navigator.pushNamed(context, '/owner-details');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Re-submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
