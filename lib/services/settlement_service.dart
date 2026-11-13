import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/settlement.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createSettlements(List<Settlement> settlements) async {
    final batch = _firestore.batch();
    for (final settlement in settlements) {
      final docRef = _firestore.collection('settlements').doc();
      batch.set(docRef, settlement.toMap());
    }
    await batch.commit();
  }

  Stream<List<Settlement>> getPendingSettlements(String groupId) {
    return _firestore
        .collection('settlements')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromFirestore(doc))
            .toList());
  }

  Stream<List<Settlement>> getAllSettlements(String groupId) {
    return _firestore
        .collection('settlements')
        .where('groupId', isEqualTo: groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromFirestore(doc))
            .toList());
  }

  Stream<List<Settlement>> getMyDebts(String userId) {
    return _firestore
        .collection('settlements')
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromFirestore(doc))
            .toList());
  }

  Stream<List<Settlement>> getMyCredits(String userId) {
    return _firestore
        .collection('settlements')
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Settlement.fromFirestore(doc))
            .toList());
  }

  Future<void> markAsSettled(String settlementId) async {
    await _firestore.collection('settlements').doc(settlementId).update({
      'status': SettlementStatus.confirmed.name,
      'settledAt': Timestamp.now(),
    });
  }

  /// Get net balances for all members in a group
  /// Positive = owed money (others owe you), Negative = owes money (you owe others)
  Future<Map<String, double>> getGroupBalances(String groupId) async {
    final snapshot = await _firestore
        .collection('settlements')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: SettlementStatus.pending.name)
        .get();

    final balances = <String, double>{};

    for (final doc in snapshot.docs) {
      final settlement = Settlement.fromFirestore(doc);
      balances[settlement.fromUserId] =
          (balances[settlement.fromUserId] ?? 0) - settlement.amount;
      balances[settlement.toUserId] =
          (balances[settlement.toUserId] ?? 0) + settlement.amount;
    }

    return balances;
  }
}
