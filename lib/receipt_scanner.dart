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

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  XFile? _image;
  Map<String, dynamic>? _receiptData; // Changed to Map to hold structured data
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _receiptData = null;
        _errorMessage = null;
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
            "totalPrice": number
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
        "totalAmount": number
      }
      If a field is not found, use null or 0 as appropriate. Translate to languages nb-NO, en-US
      ''';

      final content = [
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText != null) {
        // Clean up markdown if Gemini decides to add it anyway
        final cleanJson = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        
        try {
          final decodedData = jsonDecode(cleanJson);
          setState(() {
            _receiptData = decodedData;
          });
        } catch (e) {
           setState(() {
            _errorMessage = 'Failed to parse receipt data. Raw response: $responseText';
          });
        }
      } else {
         setState(() {
            _errorMessage = 'No response received from AI.';
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
                        child: kIsWeb 
                            ? Image.network(
                                _image!.path,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_image!.path),
                                fit: BoxFit.contain,
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item['quantity']}x ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(child: Text(item['description'] ?? '')),
                                  Text('${item['totalPrice']}'),
                                ],
                              ),
                            );
                          }),
                        const Divider(height: 24),
                        _buildSummaryRow('Subtotal', _receiptData!['subtotal']),
                        _buildSummaryRow('Tax', _receiptData!['tax']),
                        _buildSummaryRow('Tip', _receiptData!['tip']),
                        const Divider(),
                        _buildSummaryRow('Total', _receiptData!['totalAmount'], isTotal: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    // TODO: Return this data to the previous screen or save to Firestore
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt data saved!')),
                    );
                  },
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

  Widget _buildSummaryRow(String label, dynamic value, {bool isTotal = false}) {
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
            )
          ),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
