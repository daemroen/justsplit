import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../auth_service.dart';
import '../models/group.dart';
import '../models/receipt.dart';
import '../models/settlement.dart';
import '../services/group_service.dart';
import '../services/receipt_service.dart';
import '../services/settlement_service.dart';
import 'bill_splitting_screen.dart';
import 'group_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(
          'Welcome Back!',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        // Debt summary
        if (currentUserId != null) _buildDebtSummary(context, currentUserId),
        const SizedBox(height: 20),
        // Quick actions
        ElevatedButton.icon(
          onPressed: () async {
            final result =
                await Navigator.pushNamed(context, '/receipt_scanner');

            if (result != null && result is Map && context.mounted) {
              try {
                final Map<String, dynamic> typedResult =
                    Map<String, dynamic>.from(result);
                _showGroupSelectionDialog(context, typedResult);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error processing receipt data: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.camera_alt),
          label: const Text('Scan Receipt'),
        ),
        const SizedBox(height: 24),
        // Recent groups
        _buildRecentGroups(context),
        const SizedBox(height: 24),
        // Recent receipts
        if (currentUserId != null)
          _buildRecentReceipts(context, currentUserId),
      ],
    );
  }

  Widget _buildDebtSummary(BuildContext context, String userId) {
    final settlementService =
        Provider.of<SettlementService>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<Settlement>>(
            stream: settlementService.getMyDebts(userId),
            builder: (context, snapshot) {
              final debts = snapshot.data ?? [];
              final totalOwed = debts.fold<double>(
                  0, (sum, s) => sum + s.amount);

              return Card(
                color: totalOwed > 0
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color:
                            totalOwed > 0 ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalOwed.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: totalOwed > 0
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      const Text('You owe',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<Settlement>>(
            stream: settlementService.getMyCredits(userId),
            builder: (context, snapshot) {
              final credits = snapshot.data ?? [];
              final totalCredit = credits.fold<double>(
                  0, (sum, s) => sum + s.amount);

              return Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_downward,
                          color: Colors.green),
                      const SizedBox(height: 4),
                      Text(
                        totalCredit.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text('Owed to you',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentGroups(BuildContext context) {
    final groupService = Provider.of<GroupService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Groups',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Group>>(
          stream: groupService.getGroups(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No groups yet. Create one to start splitting bills!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              children: groups.take(3).map((group) {
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.group)),
                    title: Text(group.name),
                    subtitle: Text('${group.members.length} members'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GroupDetailsScreen(group: group),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentReceipts(BuildContext context, String userId) {
    final receiptService =
        Provider.of<ReceiptService>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Receipts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Receipt>>(
          stream: receiptService.getRecentReceiptsForUser(userId, limit: 5),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final receipts = snapshot.data ?? [];

            if (receipts.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No receipts yet. Scan your first receipt!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              children: receipts.map((receipt) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(receipt.restaurantName),
                    subtitle: Text(
                        '${receipt.date.day}/${receipt.date.month}/${receipt.date.year}'),
                    trailing: Text(
                      receipt.totalAmount.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // --- Dialog methods (unchanged logic) ---

  void _showGroupSelectionDialog(
      BuildContext context, Map<String, dynamic> receiptData) {
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
                onPressed: () => _showCreateGroupDialog(context),
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
                      child: Center(child: CircularProgressIndicator()));
                }

                final groups = snapshot.data ?? [];

                return ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: const Text('Personal (No Group)'),
                      subtitle: const Text('Save for yourself'),
                      onTap: () =>
                          _savePersonalReceipt(context, receiptData),
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
                            leading: const CircleAvatar(
                                child: Icon(Icons.group)),
                            title: Text(group.name),
                            subtitle:
                                Text('${group.members.length} members'),
                            onTap: () => _navigateToBillSplitting(
                                context, receiptData, group),
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
    final nameController = TextEditingController();

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
                  await groupService.createGroup(nameController.text.trim());
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Receipt _buildReceipt(Map<String, dynamic> receiptData,
      {String groupId = '', required String uploadedBy}) {
    return Receipt(
      id: const Uuid().v4(),
      groupId: groupId,
      restaurantName: receiptData['restaurantName'] ?? 'Unknown',
      date: DateTime.tryParse(receiptData['date'] ?? '') ?? DateTime.now(),
      items: (receiptData['items'] as List<dynamic>?)
              ?.map((item) =>
                  ReceiptItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (receiptData['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (receiptData['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (receiptData['tip'] as num?)?.toDouble() ?? 0.0,
      globalFees:
          List<Map<String, dynamic>>.from(receiptData['fees'] ?? []),
      globalDiscounts:
          List<Map<String, dynamic>>.from(receiptData['discounts'] ?? []),
      totalAmount:
          (receiptData['totalAmount'] as num?)?.toDouble() ?? 0.0,
      uploadedBy: uploadedBy,
      createdAt: DateTime.now(),
    );
  }

  void _navigateToBillSplitting(
      BuildContext context, Map<String, dynamic> receiptData, Group group) {
    final authService = Provider.of<AuthService>(context, listen: false);
    Navigator.pop(context);

    final receipt = _buildReceipt(
      receiptData,
      groupId: group.id,
      uploadedBy: authService.currentUser?.uid ?? 'Unknown',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BillSplittingScreen(receipt: receipt, group: group),
      ),
    );
  }

  Future<void> _savePersonalReceipt(
      BuildContext context, Map<String, dynamic> receiptData) async {
    final receiptService =
        Provider.of<ReceiptService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final receipt = _buildReceipt(
        receiptData,
        uploadedBy: authService.currentUser?.uid ?? 'Unknown',
      );

      await receiptService.addReceipt(receipt);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved to personal list!'),
            backgroundColor: Colors.green,
          ),
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
  }
}
