import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final List<Map<String, dynamic>> fees;
  final List<Map<String, dynamic>> discounts;

  ReceiptItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.fees = const [],
    this.discounts = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'fees': fees,
      'discounts': discounts,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      fees: List<Map<String, dynamic>>.from(map['fees'] ?? []),
      discounts: List<Map<String, dynamic>>.from(map['discounts'] ?? []),
    );
  }
}

class Receipt {
  final String id;
  final String groupId;
  final String restaurantName;
  final DateTime date;
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double tip;
  final List<Map<String, dynamic>> globalFees;
  final List<Map<String, dynamic>> globalDiscounts;
  final double totalAmount;
  final String uploadedBy;
  final DateTime createdAt;

  Receipt({
    required this.id,
    required this.groupId,
    required this.restaurantName,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tip,
    this.globalFees = const [],
    this.globalDiscounts = const [],
    required this.totalAmount,
    required this.uploadedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'restaurantName': restaurantName,
      'date': Timestamp.fromDate(date),
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'tip': tip,
      'fees': globalFees,
      'discounts': globalDiscounts,
      'totalAmount': totalAmount,
      'uploadedBy': uploadedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (data['tax'] as num?)?.toDouble() ?? 0.0,
      tip: (data['tip'] as num?)?.toDouble() ?? 0.0,
      globalFees: List<Map<String, dynamic>>.from(data['fees'] ?? []),
      globalDiscounts: List<Map<String, dynamic>>.from(data['discounts'] ?? []),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      uploadedBy: data['uploadedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
