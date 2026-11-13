import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_allocation.dart';

class AllocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveAllocations(List<ExpenseAllocation> allocations) async {
    final batch = _firestore.batch();
    for (final allocation in allocations) {
      final docRef = _firestore.collection('allocations').doc();
      batch.set(docRef, allocation.toMap());
    }
    await batch.commit();
  }

  Stream<List<ExpenseAllocation>> getAllocationsForReceipt(String receiptId) {
    return _firestore
        .collection('allocations')
        .where('receiptId', isEqualTo: receiptId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseAllocation.fromFirestore(doc))
            .toList());
  }

  Stream<List<ExpenseAllocation>> getAllocationsForGroup(String groupId) {
    return _firestore
        .collection('allocations')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseAllocation.fromFirestore(doc))
            .toList());
  }

  Future<void> deleteAllocationsForReceipt(String receiptId) async {
    final snapshot = await _firestore
        .collection('allocations')
        .where('receiptId', isEqualTo: receiptId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
