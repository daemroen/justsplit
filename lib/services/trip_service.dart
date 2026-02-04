import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new trip
  Future<void> createTrip(
      String name, String groupId, DateTime startDate, DateTime endDate) async {
    await _firestore.collection('trips').add({
      'name': name,
      'groupId': groupId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    });
  }

  // Get a stream of trips for a specific group
  Stream<List<Trip>> getTrips(String groupId) {
    return _firestore
        .collection('trips')
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Trip.fromFirestore(doc)).toList();
    });
  }
}
