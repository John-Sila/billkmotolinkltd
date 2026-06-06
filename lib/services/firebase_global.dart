import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetches *all* user data from `users/{uid}`.
  /// Returns a Map<String, dynamic> or null if user not logged in or not found.
  static Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();

      if (!doc.exists) return null;
      return doc.data()!;
    } catch (e) {
      // print('Error fetching user data: $e');
      return null;
    }
  }

  /// Optionally: Fetches a specific field within the user doc.
  static Future<dynamic> fetchUserField(String field) async {
    final data = await fetchUserData();
    return data?[field];
  }

  /// Optional: Real-time updates of user data via a Stream.
  static Stream<Map<String, dynamic>?> userDataStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }
}
