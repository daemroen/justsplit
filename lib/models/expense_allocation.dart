import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseAllocation {
  final String id;
  final String receiptId;
  final String groupId;
  final String userId;
  final String paidByUserId;
  final int itemIndex; // -1 means shared/equal split
  final double amount;
  final DateTime createdAt;

  ExpenseAllocation({
    required this.id,
    required this.receiptId,
    required this.groupId,
    required this.userId,
    required this.paidByUserId,
    required this.itemIndex,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiptId': receiptId,
      'groupId': groupId,
      'userId': userId,
      'paidByUserId': paidByUserId,
      'itemIndex': itemIndex,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ExpenseAllocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseAllocation(
      id: doc.id,
      receiptId: data['receiptId'] ?? '',
      groupId: data['groupId'] ?? '',
      userId: data['userId'] ?? '',
      paidByUserId: data['paidByUserId'] ?? '',
      itemIndex: data['itemIndex'] as int? ?? -1,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
