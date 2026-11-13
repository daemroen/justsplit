import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addReceipt(Receipt receipt) async {
    await _firestore.collection('receipts').add(receipt.toMap());
  }

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

  Stream<List<Receipt>> getRecentReceiptsForUser(String userId,
      {int limit = 10}) {
    return _firestore
        .collection('receipts')
        .where('uploadedBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Receipt.fromFirestore(doc)).toList());
  }

  Future<Receipt?> getReceipt(String id) async {
    final doc = await _firestore.collection('receipts').doc(id).get();
    if (doc.exists) {
      return Receipt.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateReceipt(String receiptId, Receipt receipt) async {
    await _firestore
        .collection('receipts')
        .doc(receiptId)
        .set(receipt.toMap());
  }

  Future<void> deleteReceipt(String receiptId) async {
    await _firestore.collection('receipts').doc(receiptId).delete();
  }
}
