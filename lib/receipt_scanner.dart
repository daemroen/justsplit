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

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> with SingleTickerProviderStateMixin {
  XFile? _image;
  Map<String, dynamic>? _receiptData; // Changed to Map to hold structured data
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
      
      final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');

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
      
      LOGIC FOR FEES:
      Check if the tax or other fees are already included in the unit prices.
      1. Sum up all the "totalPrice" of the items.
      2. If this sum is approximately equal to the "totalAmount" (minus any tip), then tax is ALREADY INCLUDED. In this case, the "fees" list for each item MUST BE EMPTY. Do not add tax as a fee.
      3. ONLY add tax or other charges to the "fees" list of items if the sum of item prices is LESS than the total amount (minus tip), and the missing amount corresponds to the tax/fee.
      4. If adding fees, distribute them proportionally based on the item's price.
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
  
  usageInfo = 'Input: $input | Output: $output | Thinking: $thinkingTokens | Total: $total | Cost: $cost';
}

      if (responseText != null) {
        // Clean up markdown if Gemini decides to add it anyway
        final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        
        try {
          final decodedData = jsonDecode(cleanJson);
          setState(() {
            _receiptData = decodedData;
            _tokenUsage = usageInfo;
          });
        } catch (e) {
           setState(() {
            _errorMessage = 'Failed to parse receipt data. Raw response: $responseText';
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
  final double outputCost = (actualOutputTokens / 1000000) * outputPricePerMillion;
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
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
                             if (_isLoading)
                                _buildScanningAnimation(context),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 48, color: Theme.of(context).colorScheme.secondary),
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
                onPressed: _image != null && !_isLoading ? _analyzeReceipt : null,
                icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
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
                                _receiptData!['restaurantName'] ?? 'Unknown Place',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              _receiptData!['date'] ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_receiptData!['items'] != null)
                          ...(_receiptData!['items'] as List).map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['quantity']}x ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['description'] ?? ''),
                                            if (item['translations'] != null)
                                              ...(item['translations'] as List).map((t) => 
                                                Text(
                                                  '${t['language']}: ${t['translation']}',
                                                  style: TextStyle(
                                                    fontSize: 12, 
                                                    color: Theme.of(context).colorScheme.secondary,
                                                    fontStyle: FontStyle.italic
                                                  ),
                                                )
                                              ),
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
                                        padding: const EdgeInsets.only(left: 24.0, top: 2.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '+ ${fee['description']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                            Text(
                                              '${fee['amount']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    // Display item-level discounts if they exist
                                  if (item['discounts'] != null)
                                    ...(item['discounts'] as List).map((discount) {
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 24.0, top: 2.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '- ${discount['description']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green, // Green for discounts
                                              ),
                                            ),
                                            Text(
                                              '-${discount['amount']}',
                                              style: TextStyle(
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
                              _buildSummaryRow(fee['description'], fee['amount'])
                           ),
                           
                        // Display global discounts
                        if (_receiptData!['discounts'] != null)
                           ...(_receiptData!['discounts'] as List).map((discount) => 
                              _buildSummaryRow(discount['description'], '-${discount['amount']}', color: Colors.green)
                           ),

                        _buildSummaryRow('Tax', _receiptData!['tax']),
                        _buildSummaryRow('Tip', _receiptData!['tip']),
                        const Divider(),
                        _buildSummaryRow('Total', _receiptData!['totalAmount'], isTotal: true),
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
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
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
            final double scanY = _scanController.value * constraints.maxHeight;
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
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
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

  Widget _buildSummaryRow(String label, dynamic value, {bool isTotal = false, Color? color}) {
    if (value == null || value == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
              color: color
            )
          ),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
              color: color
            ),
          ),
        ],
      ),
    );
  }
}
