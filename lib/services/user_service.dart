import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, UserProfile> _cache = {};

  /// Create or update the user's Firestore profile document after login
  Future<void> ensureUserProfile(User firebaseUser) async {
    final docRef = _firestore.collection('users').doc(firebaseUser.uid);
    await docRef.set({
      'email': firebaseUser.email ?? '',
      'displayName': firebaseUser.displayName,
      'photoUrl': firebaseUser.photoURL,
    }, SetOptions(merge: true));

    _cache[firebaseUser.uid] = UserProfile(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }

  /// Look up a single user by UID (cache-first)
  Future<UserProfile?> getUserProfile(String uid) async {
    if (_cache.containsKey(uid)) {
      return _cache[uid];
    }

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final profile = UserProfile.fromFirestore(doc);
    _cache[uid] = profile;
    return profile;
  }

  /// Look up multiple users by UID (batch-efficient)
  Future<Map<String, UserProfile>> getUserProfiles(List<String> uids) async {
    final result = <String, UserProfile>{};
    final uncachedUids = <String>[];

    for (final uid in uids) {
      if (_cache.containsKey(uid)) {
        result[uid] = _cache[uid]!;
      } else {
        uncachedUids.add(uid);
      }
    }

    // Firestore 'in' queries support max 30 items
    for (var i = 0; i < uncachedUids.length; i += 30) {
      final batch = uncachedUids.skip(i).take(30).toList();
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      for (final doc in snapshot.docs) {
        final profile = UserProfile.fromFirestore(doc);
        _cache[profile.uid] = profile;
        result[profile.uid] = profile;
      }
    }

    return result;
  }

  /// Search users by email prefix (for member invitation)
  Future<List<UserProfile>> searchUsersByEmail(String emailQuery) async {
    if (emailQuery.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: emailQuery)
        .where('email', isLessThan: '$emailQuery\uf8ff')
        .limit(10)
        .get();

    return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
  }
}
