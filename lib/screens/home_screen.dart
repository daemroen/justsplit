import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';
import '../models/group.dart';
import '../services/group_service.dart';
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
            if (result != null && result is Map<String, dynamic> && context.mounted) {
              _showGroupSelectionDialog(context, result);
            }
          },
          child: const Text('Scan Receipt'),
        ),
        const SizedBox(height: 30),
        _buildRecentActivity(context),
      ],
    );
  }

  void _showGroupSelectionDialog(BuildContext context, Map<String, dynamic> receiptData) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final receiptService = Provider.of<ReceiptService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Group'),
          content: StreamBuilder<List<Group>>(
            stream: groupService.getGroups(),
            builder: (context, snapshot) {
               if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No groups found. Please create a group first.');
              }
              final groups = snapshot.data!;
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      title: Text(group.name),
                      onTap: () async {
                         try {
                           final receipt = Receipt(
                             id: const Uuid().v4(), // Generate a new ID
                             groupId: group.id,
                             restaurantName: receiptData['restaurantName'] ?? 'Unknown',
                             date: DateTime.tryParse(receiptData['date'] ?? '') ?? DateTime.now(),
                             items: (receiptData['items'] as List<dynamic>?)
                                     ?.map((item) => ReceiptItem.fromMap(item))
                                     .toList() ??
                                 [],
                             subtotal: (receiptData['subtotal'] as num?)?.toDouble() ?? 0.0,
                             tax: (receiptData['tax'] as num?)?.toDouble() ?? 0.0,
                             tip: (receiptData['tip'] as num?)?.toDouble() ?? 0.0,
                             globalFees: List<Map<String, dynamic>>.from(receiptData['fees'] ?? []),
                             globalDiscounts: List<Map<String, dynamic>>.from(receiptData['discounts'] ?? []),
                             totalAmount: (receiptData['totalAmount'] as num?)?.toDouble() ?? 0.0,
                             uploadedBy: authService.user?.email ?? 'Unknown',
                             createdAt: DateTime.now(),
                           );
                           
                           await receiptService.addReceipt(receipt);
                           
                           if (context.mounted) {
                             Navigator.pop(context); // Close dialog
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Receipt saved to ${group.name}!')),
                             );
                           }
                         } catch (e) {
                           if (context.mounted) {
                             Navigator.pop(context);
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error saving receipt: $e')),
                             );
                           }
                         }
                      },
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
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
