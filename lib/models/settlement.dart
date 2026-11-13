import 'package:cloud_firestore/cloud_firestore.dart';

enum SettlementStatus { pending, confirmed }

class Settlement {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final SettlementStatus status;
  final String? receiptId;
  final DateTime createdAt;
  final DateTime? settledAt;
  final String? note;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    required this.status,
    this.receiptId,
    required this.createdAt,
    this.settledAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'status': status.name,
      'receiptId': receiptId,
      'createdAt': Timestamp.fromDate(createdAt),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'note': note,
    };
  }

  factory Settlement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Settlement(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: SettlementStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => SettlementStatus.pending,
      ),
      receiptId: data['receiptId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      settledAt: (data['settledAt'] as Timestamp?)?.toDate(),
      note: data['note'] as String?,
    );
  }
}
