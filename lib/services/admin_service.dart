import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. Stream to monitor total dynamic users counter real-time
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  // 2. Stream to compute overall live ticket bookings data for metrics calculation
  Stream<QuerySnapshot> getTicketsStream() {
    return _firestore.collection('tickets').snapshots();
  }

  // 3. Control Action: Safely delete fake users and drop credentials validation indices
  Future<void> removeUserPermanently(String uid) async {
    // Transactional batch delete (removes core account profile data)
    await _firestore.collection('users').doc(uid).delete();
  }

  // 4. Control Action: Toggle block parameters state safely
  Future<void> toggleUserBlockStatus(String uid, bool currentBlockState) async {
    await _firestore.collection('users').doc(uid).update({
      'isBlocked': !currentBlockState,
    });
  }
}