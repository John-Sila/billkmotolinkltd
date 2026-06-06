import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  static Future<bool> getFreeAssignment() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      final data = doc.data();
      return data?['freeAssignment'] ?? false;
    } catch (e) {
      return false;
    }
  }
}