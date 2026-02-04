import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new receipt
  Future<void> addReceipt(Receipt receipt) async {
    await _firestore.collection('receipts').add(receipt.toMap());
  }

  // Get receipts for a specific group
  Stream<List<Receipt>> getReceiptsForGroup(String groupId) {
    return _firestore
        .collection('receipts')
        .where('groupId', isEqualTo: groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Receipt.fromFirestore(doc)).toList();
    });
  }

  // Get a single receipt by ID
  Future<Receipt?> getReceipt(String id) async {
    final doc = await _firestore.collection('receipts').doc(id).get();
    if (doc.exists) {
      return Receipt.fromFirestore(doc);
    }
    return null;
  }
}
