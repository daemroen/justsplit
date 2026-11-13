import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createGroup(String name) async {
    final User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('groups').add({
        'name': name,
        'members': [user.uid],
        'createdBy': user.uid,
        'createdAt': Timestamp.now(),
        'currency': 'NOK',
      });
    }
  }

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
      return snapshot.docs.map((doc) => Group.fromFirestore(doc)).toList();
    });
  }

  Stream<Group> streamGroup(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((doc) => Group.fromFirestore(doc));
  }

  Future<Group?> getGroupById(String groupId) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromFirestore(doc);
  }

  Future<void> addMember(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> addGuestMember(String groupId, String name) async {
    await _firestore.collection('groups').doc(groupId).update({
      'guestMembers': FieldValue.arrayUnion([name]),
    });
  }

  Future<void> removeGuestMember(String groupId, String name) async {
    await _firestore.collection('groups').doc(groupId).update({
      'guestMembers': FieldValue.arrayRemove([name]),
    });
  }

  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
  }

  Future<void> updateGroup(String groupId, {String? name, String? currency}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (currency != null) updates['currency'] = currency;
    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
  }
}
