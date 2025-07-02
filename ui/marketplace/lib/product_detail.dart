

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/${widget.productId}/'));
      if (response.statusCode == 200) {
        setState(() {
          _product = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Failed to load product');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Product Details")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text("Product not found"))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_product!['image'] != null)
                        Center(
                          child: Image.network(
                            _product!['image'].toString().startsWith('https')
                                ? _product!['image']
                                : '${mediaRootBaseUrl}${_product!['image']}',
                            height: 200,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _product!['name'],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('₹${_product!['price']}', style: const TextStyle(fontSize: 18, color: Colors.indigo)),
                      // Quantity selector
                      Row(
                        children: [
                          const Text('Quantity:', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                if (_quantity > 1) _quantity--;
                              });
                            },
                          ),
                          Text('$_quantity', style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                _quantity++;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(_product!['description'] ?? '', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      Text('Sold by: ${_product!['seller']}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      // Buy Now button at the end
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final url = Uri.parse('$baseUrl/orders/');
                            try {
                              final response = await http.post(
                                url,
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'customer_id': 1,  // Replace with actual user id when available
                                  'items': [
                                    {
                                      'product_id': _product!['id'],
                                      'quantity': _quantity,
                                    }
                                  ]
                                }),
                              );

                              if (response.statusCode == 200) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Order placed successfully!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to place order: ${response.statusCode}')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error placing order: $e')),
                              );
                            }
                          },
                          child: const Text('Buy Now', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}