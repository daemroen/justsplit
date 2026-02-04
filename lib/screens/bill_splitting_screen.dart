import 'package:flutter/material.dart';

class BillSplittingScreen extends StatelessWidget {
  const BillSplittingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Splitting'),
      ),
      body: const Center(
        child: Text('Receipt scanning and bill splitting will be implemented here.'),
      ),
    );
  }
}
