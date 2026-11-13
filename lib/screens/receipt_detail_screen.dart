import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../services/receipt_service.dart';
import 'receipt_edit_screen.dart';

class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  final String currency;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    this.currency = 'NOK',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(receipt.restaurantName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptEditScreen(
                    receipt: receipt,
                    currency: currency,
                  ),
                ),
              );
              if (updated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.restaurantName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${receipt.date.day}/${receipt.date.month}/${receipt.date.year}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...receipt.items.map((item) => Card(
                child: ListTile(
                  title: Text(item.description),
                  subtitle: Text(
                      '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}'),
                  trailing: Text(
                    '${item.totalPrice.toStringAsFixed(2)} $currency',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),

          const SizedBox(height: 16),
          const Divider(),

          // Totals
          _buildTotalRow('Subtotal', receipt.subtotal),
          if (receipt.tax > 0) _buildTotalRow('Tax', receipt.tax),
          if (receipt.tip > 0) _buildTotalRow('Tip', receipt.tip),
          ...receipt.globalFees.map((fee) => _buildTotalRow(
                fee['name'] ?? 'Fee',
                (fee['amount'] as num?)?.toDouble() ?? 0,
              )),
          ...receipt.globalDiscounts.map((disc) => _buildTotalRow(
                disc['name'] ?? 'Discount',
                -((disc['amount'] as num?)?.toDouble() ?? 0),
              )),
          const Divider(),
          _buildTotalRow('Total', receipt.totalAmount, isBold: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} $currency',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text(
            'Are you sure you want to delete this receipt? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final receiptService =
                  Provider.of<ReceiptService>(context, listen: false);
              await receiptService.deleteReceipt(receipt.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Close detail screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
