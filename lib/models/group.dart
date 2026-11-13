import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final List<String> members; // Firebase Auth UIDs
  final List<String> guestMembers; // Names of people without accounts
  final String createdBy;
  final DateTime createdAt;
  final String currency;

  Group({
    required this.id,
    required this.name,
    required this.members,
    this.guestMembers = const [],
    required this.createdBy,
    required this.createdAt,
    this.currency = 'NOK',
  });

  /// All member identifiers: UIDs for registered users, "guest:Name" for guests
  List<String> get allMemberIds => [
        ...members,
        ...guestMembers.map((name) => 'guest:$name'),
      ];

  /// Check if an ID is a guest
  static bool isGuest(String id) => id.startsWith('guest:');

  /// Extract guest name from ID
  static String guestName(String id) => id.substring(6);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'members': members,
      'guestMembers': guestMembers,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'currency': currency,
    };
  }

  factory Group.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Group(
      id: doc.id,
      name: data['name'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      guestMembers: List<String>.from(data['guestMembers'] ?? []),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currency: data['currency'] as String? ?? 'NOK',
    );
  }
}
