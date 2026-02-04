import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new group
  Future<void> createGroup(String name) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('groups').add({
        'name': name,
        'members': [user.uid],
        'createdAt': Timestamp.now(),
      });
    }
  }

  // Get a stream of groups for the current user
  Stream<List<Group>> getGroups() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('groups')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Group(
          id: doc.id,
          name: doc['name'],
          members: List<String>.from(doc['members']),
        );
      }).toList();
    });
  }
}
