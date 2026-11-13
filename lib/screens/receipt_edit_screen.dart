import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/receipt.dart';
import '../services/receipt_service.dart';

class ReceiptEditScreen extends StatefulWidget {
  final Receipt receipt;
  final String currency;

  const ReceiptEditScreen({
    super.key,
    required this.receipt,
    this.currency = 'NOK',
  });

  @override
  State<ReceiptEditScreen> createState() => _ReceiptEditScreenState();
}

class _ReceiptEditScreenState extends State<ReceiptEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _taxController;
  late TextEditingController _tipController;
  late List<_ItemEditing> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.receipt.restaurantName);
    _taxController =
        TextEditingController(text: widget.receipt.tax.toStringAsFixed(2));
    _tipController =
        TextEditingController(text: widget.receipt.tip.toStringAsFixed(2));
    _items = widget.receipt.items
        .map((item) => _ItemEditing(
              description: TextEditingController(text: item.description),
              quantity:
                  TextEditingController(text: item.quantity.toString()),
              unitPrice: TextEditingController(
                  text: item.unitPrice.toStringAsFixed(2)),
            ))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taxController.dispose();
    _tipController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Receipt'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Restaurant Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: _addItem,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: item.description,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () => _removeItem(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: item.quantity,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: item.unitPrice,
                            decoration: InputDecoration(
                              labelText: 'Price (${widget.currency})',
                              isDense: true,
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Tax and Tip
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taxController,
                  decoration: InputDecoration(
                    labelText: 'Tax (${widget.currency})',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _tipController,
                  decoration: InputDecoration(
                    labelText: 'Tip (${widget.currency})',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemEditing(
        description: TextEditingController(),
        quantity: TextEditingController(text: '1'),
        unitPrice: TextEditingController(text: '0.00'),
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final items = _items.map((item) {
        final qty = double.tryParse(item.quantity.text) ?? 1;
        final price = double.tryParse(item.unitPrice.text) ?? 0;
        return ReceiptItem(
          description: item.description.text,
          quantity: qty,
          unitPrice: price,
          totalPrice: qty * price,
        );
      }).toList();

      final tax = double.tryParse(_taxController.text) ?? 0;
      final tip = double.tryParse(_tipController.text) ?? 0;
      final subtotal =
          items.fold<double>(0, (sum, item) => sum + item.totalPrice);

      final updatedReceipt = Receipt(
        id: widget.receipt.id,
        groupId: widget.receipt.groupId,
        restaurantName: _nameController.text.trim(),
        date: widget.receipt.date,
        items: items,
        subtotal: subtotal,
        tax: tax,
        tip: tip,
        globalFees: widget.receipt.globalFees,
        globalDiscounts: widget.receipt.globalDiscounts,
        totalAmount: subtotal + tax + tip,
        uploadedBy: widget.receipt.uploadedBy,
        createdAt: widget.receipt.createdAt,
      );

      final receiptService =
          Provider.of<ReceiptService>(context, listen: false);
      await receiptService.updateReceipt(widget.receipt.id, updatedReceipt);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt updated'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _ItemEditing {
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemEditing({
    required this.description,
    required this.quantity,
    required this.unitPrice,
  });

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}
