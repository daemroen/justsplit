import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // Nødvendig for kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with SingleTickerProviderStateMixin {
  XFile? _image;
  Map<String, dynamic>?
      _receiptData; // Changed to Map to hold structured data
  bool _isLoading = false;
  String? _errorMessage;
  String? _tokenUsage; // State variable for token usage
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _receiptData = null;
        _errorMessage = null;
        _tokenUsage = null;
      });
    }
  }

  Future<void> _analyzeReceipt() async {
    if (_image == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _receiptData = null;
      _errorMessage = null;
      _tokenUsage = null;
    });

    try {
      final imageBytes = await _image!.readAsBytes();

      final model =
          FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');

      const prompt = '''
      Analyze this receipt image and extract structured data. 
      Return ONLY a valid JSON object. Do not use Markdown code blocks. 
      The JSON must have this structure:
      {
        "restaurantName": "string",
        "date": "string (YYYY-MM-DD)",
        "items": [
          {
            "description": "string",
            "quantity": number,
            "unitPrice": number,
            "totalPrice": number,
            "translations": [
              {
                "language": "string",
                "translation": "string"
              }
            ]
          }
        ],
        "subtotal": number,
        "tax": number,
        "tip": number,
        "fees": [
           {
              "description": "string",
              "amount": number
            }
        ],
        "discounts": [
           {
              "description": "string",
              "amount": number
            }
        ],
        "totalAmount": number
      }
      If a field is not found, use null or 0 as appropriate. Translate to languages nb-NO, en-US.
      Do not calculate per-item fees or discounts in the JSON. Just extract the raw global values in fees or discounts.
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;

      // Extract token usage if available
      String? usageInfo;
      if (response.usageMetadata != null) {
        final input = response.usageMetadata!.promptTokenCount ?? 0;
        final output = response.usageMetadata!.candidatesTokenCount ?? 0;
        final total = response.usageMetadata!.totalTokenCount ?? 0;
        final thinkingTokens = total - input - output;
        final cost = _calculateCost(input, output, total);

        usageInfo =
            'Input: $input | Output: $output | Thinking: $thinkingTokens | Total: $total | Cost: $cost';
      }

      if (responseText != null) {
        // Clean up markdown if Gemini decides to add it anyway
        final cleanJson = responseText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        try {
          final decodedData = jsonDecode(cleanJson);
          
          // Process the data to distribute fees and discounts
          final processedData = _processReceiptData(decodedData);

          setState(() {
            _receiptData = processedData;
            _tokenUsage = usageInfo;
          });
        } catch (e) {
          setState(() {
            _errorMessage =
                'Failed to parse receipt data. Raw response: $responseText';
            _tokenUsage = usageInfo;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No response received from AI.';
          _tokenUsage = usageInfo;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error analyzing image: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _processReceiptData(Map<String, dynamic> data) {
    // Clone the data to avoid modifying the original if passed by reference (though jsonDecode usually creates new)
    final Map<String, dynamic> newData = Map<String, dynamic>.from(data);
    
    final List<dynamic> items = (newData['items'] as List<dynamic>?) ?? [];
    if (items.isEmpty) return newData;

    // Initialize fees and discounts arrays on items if they don't exist
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        item['fees'] = [];
        item['discounts'] = [];
      }
    }

    double totalItemPrice = 0.0;
    for (var item in items) {
       totalItemPrice += (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
    }

    if (totalItemPrice == 0) return newData;

    final double totalAmount = (newData['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final double tip = (newData['tip'] as num?)?.toDouble() ?? 0.0;
    final double tax = (newData['tax'] as num?)?.toDouble() ?? 0.0;
    
    final List<dynamic> globalFees = (newData['fees'] as List<dynamic>?) ?? [];
    final List<dynamic> globalDiscounts = (newData['discounts'] as List<dynamic>?) ?? [];

    double sumGlobalFees = 0.0;
    for (var fee in globalFees) {
      sumGlobalFees += (fee['amount'] as num?)?.toDouble() ?? 0.0;
    }

    double sumGlobalDiscounts = 0.0;
    for (var discount in globalDiscounts) {
      sumGlobalDiscounts += (discount['amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 1. Distribute explicit global fees
    for (var fee in globalFees) {
      _distributeToItems(items, totalItemPrice, fee['description'] ?? 'Fee', (fee['amount'] as num?)?.toDouble() ?? 0.0, isFee: true);
    }

    // 2. Distribute explicit global discounts
    for (var discount in globalDiscounts) {
      _distributeToItems(items, totalItemPrice, discount['description'] ?? 'Discount', (discount['amount'] as num?)?.toDouble() ?? 0.0, isFee: false);
    }

    // 3. Handle Tax and Implicit Fees
    // Check if tax is additive
    // Expected Total if tax is additive = Items + Tax + Fees - Discounts + Tip
    double expectedAdditiveTotal = totalItemPrice + tax + sumGlobalFees - sumGlobalDiscounts + tip;
    
    // Allow a small margin of error (e.g. 1.0)
    bool isTaxAdditive = (expectedAdditiveTotal - totalAmount).abs() < 1.0;

    if (isTaxAdditive && tax > 0) {
      // Tax is additive, distribute it
      _distributeToItems(items, totalItemPrice, 'Tax', tax, isFee: true);
    } else {
      // Tax is likely included OR there is a discrepancy.
      // Check for discrepancy: Real Total - (Items + Fees - Discounts + Tip)
      // Note: If Tax is included, it is part of "Items", so we don't subtract it separately from calculation here.
      // We assume items includes tax if we are here.
      
      double calculatedTotal = totalItemPrice + sumGlobalFees - sumGlobalDiscounts + tip;
      double discrepancy = totalAmount - calculatedTotal;

      if (discrepancy.abs() > 0.1) {
        if (discrepancy > 0) {
          // Missing charges (could be tax that wasn't explicitly labeled as such in a way that matches, or other fees)
          // Only add if it looks like the tax amount (if tax was found but deemed not additive by exact match, maybe discrepancy matches tax?)
           if (tax > 0 && (discrepancy - tax).abs() < 0.1) {
              _distributeToItems(items, totalItemPrice, 'Tax', tax, isFee: true);
           } else {
              _distributeToItems(items, totalItemPrice, 'Extra Charges', discrepancy, isFee: true);
           }
        } else {
           // Negative discrepancy implies a discount not accounted for
           _distributeToItems(items, totalItemPrice, 'Discount', discrepancy.abs(), isFee: false);
        }
      }
    }

    return newData;
  }

  void _distributeToItems(List<dynamic> items, double totalItemPrice, String description, double amount, {required bool isFee}) {
    if (amount <= 0) return;
    
    for (var item in items) {
      double itemPrice = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
      double share = (itemPrice / totalItemPrice) * amount;
      // Round to 2 decimals
      share = (share * 100).round() / 100;
      
      if (share > 0) {
        if (isFee) {
           item['fees'].add({
             'description': description,
             'amount': share
           });
        } else {
           item['discounts'].add({
             'description': description,
             'amount': share
           });
        }
      }
    }
  }

  void _saveReceipt() {
    if (_receiptData != null) {
      Navigator.pop(context, _receiptData);
    }
  }

  String _calculateCost(int inputTokens, int outputTokens, int totalTokens) {
    // Gemini 2.5 Flash priser (per 1 million tokens)
    const double inputPricePerMillion = 0.30;
    const double outputPricePerMillion = 2.50; // inkluderer thinking tokens

    // Beregn faktisk output (inkl. thinking tokens)
    final int actualOutputTokens = totalTokens - inputTokens;

    final double inputCost = (inputTokens / 1000000) * inputPricePerMillion;
    final double outputCost =
        (actualOutputTokens / 1000000) * outputPricePerMillion;
    final double totalCost = inputCost + outputCost;

    return '\$${totalCost.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Image Preview Area
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            kIsWeb
                                ? Image.network(
                                    _image!.path,
                                    fit: BoxFit.contain,
                                  )
                                : Image.file(
                                    File(_image!.path),
                                    fit: BoxFit.contain,
                                  ),
                            if (_isLoading) _buildScanningAnimation(context),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 48,
                                color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(height: 8),
                            const Text('No receipt selected'),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    _image != null && !_isLoading ? _analyzeReceipt : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics),
                label: Text(_isLoading ? 'Processing...' : 'Analyze Receipt'),
              ),

              const SizedBox(height: 30),

              // Error Display
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),

              // Results Display
              if (_receiptData != null) ...[
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _receiptData!['restaurantName'] ??
                                    'Unknown Place',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              _receiptData!['date'] ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text('Items',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_receiptData!['items'] != null)
                          ...(_receiptData!['items'] as List).map((item) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['quantity']}x ',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item['description'] ?? ''),
                                            if (item['translations'] != null)
                                              ...(item['translations'] as List)
                                                  .map((t) => Text(
                                                        '${t['language']}: ${t['translation']}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .secondary,
                                                            fontStyle: FontStyle
                                                                .italic),
                                                      )),
                                          ],
                                        ),
                                      ),
                                      Text('${item['totalPrice']}'),
                                    ],
                                  ),
                                  // Display item-level fees if they exist
                                  if (item['fees'] != null)
                                    ...(item['fees'] as List).map((fee) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            left: 24.0, top: 2.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '+ ${fee['description']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                              ),
                                            ),
                                            Text(
                                              '${fee['amount']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  // Display item-level discounts if they exist
                                  if (item['discounts'] != null)
                                    ...(item['discounts'] as List)
                                        .map((discount) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            left: 24.0, top: 2.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '- ${discount['description']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors
                                                    .green, // Green for discounts
                                              ),
                                            ),
                                            Text(
                                              '-${discount['amount']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          }),
                        const Divider(height: 24),
                        _buildSummaryRow('Subtotal', _receiptData!['subtotal']),

                        // Display global fees
                        if (_receiptData!['fees'] != null)
                          ...(_receiptData!['fees'] as List).map((fee) =>
                              _buildSummaryRow(
                                  fee['description'], fee['amount'])),

                        // Display global discounts
                        if (_receiptData!['discounts'] != null)
                          ...(_receiptData!['discounts'] as List).map(
                              (discount) => _buildSummaryRow(
                                  discount['description'],
                                  '-${discount['amount']}',
                                  color: Colors.green)),

                        _buildSummaryRow('Tax', _receiptData!['tax']),
                        _buildSummaryRow('Tip', _receiptData!['tip']),
                        const Divider(),
                        _buildSummaryRow(
                            'Total', _receiptData!['totalAmount'],
                            isTotal: true),
                      ],
                    ),
                  ),
                ),

                // Token Usage Display
                if (_tokenUsage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _tokenUsage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saveReceipt,
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green),
                  child: const Text('Save Receipt'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningAnimation(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _scanController,
          builder: (context, child) {
            final double scanY =
                _scanController.value * constraints.maxHeight;
            return Stack(
              children: [
                // Semi-transparent overlay to make the scan line pop
                Container(color: Colors.black.withOpacity(0.1)),

                // The scanning line
                Positioned(
                  top: scanY,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.8),
                          blurRadius: 10.0,
                          spreadRadius: 2.0,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 5.0,
                          spreadRadius: 0.0,
                        ),
                      ],
                    ),
                  ),
                ),

                // Optional: A gradient trail fading out behind the line could be added here
                // For now, the glow effect is "magical" enough.
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, dynamic value,
      {bool isTotal = false, Color? color}) {
    if (value == null || value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 18 : 14,
                  color: color)),
          Text(
            '$value',
            style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 18 : 14,
                color: color),
          ),
        ],
      ),
    );
  }
}
