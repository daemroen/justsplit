import 'package:flutter/material.dart';
import '../receipt_scanner.dart'; // Import ReceiptScannerScreen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(
          'Welcome Back!',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        Text(
          'Here\'s a look at your recent activity.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () async {
            // Wait for the result from the receipt scanner
            final result = await Navigator.pushNamed(context, '/receipt_scanner');
            
            // Check if we got data back
            if (result != null && result is Map<String, dynamic>) {
              // Show a snackbar or handle the data
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Receipt saved from ${result['restaurantName']}! Total: ${result['totalAmount']}'),
                    duration: const Duration(seconds: 4),
                  ),
                );
                // Here you would typically save this to Firestore or update the UI state
              }
            }
          },
          child: const Text('Scan Receipt'),
        ),
        const SizedBox(height: 30),
        _buildRecentActivity(context),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Groups',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Bali Trip'),
            subtitle: const Text('You spent \$540'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recent Expenses',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Dinner at a local restaurant'),
            subtitle: const Text('You paid \$45'),
            trailing: const Text('View Details'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
