import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  bool _isLoading = true;
  late List<bool> hoverStates;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/'));
      if (response.statusCode == 200) {
        setState(() {
          _products = jsonDecode(response.body);
          hoverStates = List<bool>.filled(_products.length, false);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Failed to load products');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LastMinute Marketplace'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 2 / 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final product = _products[index];
                return MouseRegion(
                  onEnter: (_) => setState(() => hoverStates[index] = true),
                  onExit: (_) => setState(() => hoverStates[index] = false),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/product/${product['id']}');
                    },
                    child: AnimatedScale(
                      scale: hoverStates[index] ? 1.03 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Card(
                        elevation: hoverStates[index] ? 10 : 4,
                        color: hoverStates[index] ? Colors.indigo.shade50 : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: product['image'] != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.network(
                                          product['image'].toString().startsWith('http')
                                              ? product['image']
                                              : '${serverUrl}/${product['image']}',
                                          fit: BoxFit.contain,
                                          height: 80,
                                          width: 80,
                                          alignment: Alignment.center,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                        ),
                                      )
                                    : const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Text(product['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('₹${product['price']}', style: const TextStyle(color: Colors.indigo)),
                              const SizedBox(height: 2),
                              Text(product['seller'],
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}