import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SideNavigation extends StatelessWidget {
  final String customerName;
  final Function(String) onItemSelected;

  const SideNavigation({
    Key? key,
    required this.customerName,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Colors.grey[100],
      child: Column(
        children: [
          const SizedBox(height: 100),
          // Profile Section
          GestureDetector(
            onTap: () => onItemSelected('home'),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(
                    'https://api.dicebear.com/7.x/shapes/png?seed=$customerName',
                  ),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(height: 12),
                Text(
                  customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Navigation Items
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('History'),
            onTap: () => onItemSelected('bookings-list'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support'),
            onTap: () async {
            final url = Uri.parse('https://wa.me/918141254708?text=Hi%2C%20I%20need%20help');
            try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
            } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open WhatsApp.')),
                );
            }
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Use'),
            onTap: () => onItemSelected('terms'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => onItemSelected('logout'),
          ),

          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              '© 2025 LastMinute',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        ],
      ),
    );
  }
}