import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth_service.dart';
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
            final result = await Navigator.pushNamed(context, '/receipt_scanner');
            
            if (result != null && result is Map && context.mounted) {
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Group'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Create New Group',
                onPressed: () {
                  _showCreateGroupDialog(context);
                },
              ),
            ],
          ),
          content: SizedBox(
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
                
                final groups = snapshot.data ?? [];
                
                return ListView(
                  shrinkWrap: true,
                  children: [
                    // Option to save without a group (Personal)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: const Text('Personal (No Group)'),
                      subtitle: const Text('Save for yourself'),
                      onTap: () => _saveReceipt(context, receiptData, null),
                    ),
                    const Divider(),
                    if (groups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No groups found.', 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...groups.map((group) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.group)),
                        title: Text(group.name),
                        subtitle: Text('${group.members.length} members'),
                        onTap: () => _saveReceipt(context, receiptData, group),
                      )),
                  ],
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

  void _showCreateGroupDialog(BuildContext context) {
    final groupService = Provider.of<GroupService>(context, listen: false);
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Group'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Group Name',
              hintText: 'e.g. Summer Trip, Roommates',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  try {
                    await groupService.createGroup(nameController.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context); // Close create dialog
                      // The stream in selection dialog will update automatically
                    }
                  } catch (e) {
                    // Handle error
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveReceipt(BuildContext context, Map<String, dynamic> receiptData, Group? group) async {
    final receiptService = Provider.of<ReceiptService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Show loading
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator())
    );

    try {
      final receipt = Receipt(
        id: const Uuid().v4(),
        groupId: group?.id ?? '', // Empty string for personal receipt
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
        uploadedBy: authService.currentUser?.email ?? 'Unknown',
        createdAt: DateTime.now(),
      );
      
      await receiptService.addReceipt(receipt);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close selection dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(group != null 
              ? 'Receipt saved to ${group.name}!' 
              : 'Receipt saved to personal list!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving receipt: $e')),
        );
      }
    }
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
