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
            // We use 'is Map' to be safer with types coming from jsonDecode
            if (result != null && result is Map && context.mounted) {
              // Cast to Map<String, dynamic> safely
              try {
                final Map<String, dynamic> typedResult = Map<String, dynamic>.from(result);
                _showGroupSelectionDialog(context, typedResult);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error processing receipt data: $e')),
                );
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

  void _showGroupSelectionDialog(BuildContext context, Map<String, dynamic> receiptData) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final receiptService = Provider.of<ReceiptService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Group'),
          content: SizedBox( // Limit size to avoid layout issues
            width: double.maxFinite,
            child: StreamBuilder<List<Group>>(
              stream: groupService.getGroups(),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator())
                  );
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No groups found. Please create a group first.'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to groups screen or show create dialog
                          Navigator.pop(context);
                          // Ideally navigate to Groups tab, but for now just close
                        },
                         child: const Text('Close'),
                      )
                    ],
                  );
                }
                final groups = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.group)),
                      title: Text(group.name),
                      subtitle: Text('${group.members.length} members'),
                      onTap: () async {
                         try {
                           // Show loading indicator
                           showDialog(
                             context: context, 
                             barrierDismissible: false,
                             builder: (ctx) => const Center(child: CircularProgressIndicator())
                           );

                           final receipt = Receipt(
                             id: const Uuid().v4(),
                             groupId: group.id,
                             restaurantName: receiptData['restaurantName'] ?? 'Unknown',
                             date: DateTime.tryParse(receiptData['date'] ?? '') ?? DateTime.now(),
                             items: (receiptData['items'] as List<dynamic>?)
                                     ?.map((item) => ReceiptItem.fromMap(item as Map<String, dynamic>))
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
                             Navigator.pop(context); // Close loading
                             Navigator.pop(context); // Close selection dialog
                             
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(
                                 content: Text('Receipt saved to ${group.name}!'),
                                 backgroundColor: Colors.green,
                               ),
                             );
                           }
                         } catch (e) {
                           if (context.mounted) {
                             Navigator.pop(context); // Close loading
                             // Don't close selection dialog so they can try again
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error saving receipt: $e')),
                             );
                           }
                         }
                      },
                    );
                  },
                );
              },
            ),
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
