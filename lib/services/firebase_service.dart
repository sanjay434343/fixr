import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get all services
  Future<Map<String, dynamic>> getAllServices() async {
    try {
      DataSnapshot snapshot = await _database.ref().child('services').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  // Get services by category
  Future<Map<String, dynamic>> getServicesByCategory(String category) async {
    try {
      DataSnapshot snapshot = await _database.ref().child('services').child(category).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to load $category services: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    try {
      DataSnapshot snapshot = await _database.ref().child('users').child(uid).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return {};
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }
}
