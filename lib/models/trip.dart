import 'package:cloud_firestore/cloud_firestore.dart';

class Trip {
  final String id;
  final String name;
  final String groupId;
  final DateTime startDate;
  final DateTime endDate;

  Trip({
    required this.id,
    required this.name,
    required this.groupId,
    required this.startDate,
    required this.endDate,
  });

  factory Trip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Trip(
      id: doc.id,
      name: data['name'],
      groupId: data['groupId'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
    );
  }
}
