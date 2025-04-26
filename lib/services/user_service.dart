import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<UserModel?> getUserData(String uid) async {
    try {
      // Verify current user
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('Unauthorized access');
      }

      // Get user data from their specific node
      final snapshot = await _db.child('users/$uid').get();
      if (!snapshot.exists) return null;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return UserModel(
        uid: uid,
        name: data['name'] ?? 'Guest User',
        email: data['email'] ?? '',
        phone: data['phone'] ?? '',
        address: data['address'] ?? '',
        doornum: data['doornum'] ?? '',
        landmark: data['landmark'] ?? '',
        createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  Future<bool> updateUserName(String uid, String name) async {
    try {
      await _db.child('users/$uid').update({'name': name});
      return true;
    } catch (e) {
      print('Error updating user name: $e');
      return false;
    }
  }

  Future<bool> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _db.child('users/$uid').update(updates);
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  Future<bool> createUserData(String uid, UserModel user) async {
    try {
      await _db.child('users/$uid').set(user.toJson());
      return true;
    } catch (e) {
      print('Error creating user data: $e');
      return false;
    }
  }
}
