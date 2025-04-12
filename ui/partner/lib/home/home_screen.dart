import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Home'),
        backgroundColor: Colors.indigo,
      ),
      body: const Center(
        child: Text(
          'Welcome, Driver!',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}