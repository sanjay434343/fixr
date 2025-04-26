import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final _database = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  DatabaseReference _userRef(String uid) => _database.ref().child('users').child(uid);

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String address,
    required String doornum,
    required String landmark,
    String? fcmToken,
  }) async {
    try {
      await _userRef(uid).set({
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'doornum': doornum,
        'landmark': landmark,
        'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
        'fcmToken': fcmToken ?? '',
      });
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // User data methods
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final snapshot = await _database.ref()
          .child('users')
          .child(user.uid)
          .once();

      if (!snapshot.snapshot.exists) return null;
      return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Bookings methods
  Stream<DatabaseEvent> getUserBookings() {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    return _database.ref()
        .child('user_bookings')
        .child(user.uid)
        .orderByChild('timestamp')
        .onValue;
  }

  // Services methods (public access)
  Stream<DatabaseEvent> getServices() {
    return _database.ref().child('services').onValue;
  }

  // Service Persons methods (public access)
  Stream<DatabaseEvent> getServicePersons() {
    return _database.ref().child('servicePersons').onValue;
  }

  // App version (public access)
  Future<String?> getAppVersion() async {
    try {
      final snapshot = await _database.ref()
          .child('appversion')
          .child('current')
          .once();
      return snapshot.snapshot.value?.toString();
    } catch (e) {
      print('Error getting app version: $e');
      return null;
    }
  }

  // Generic database operation wrapper
  Future<T> guardedDatabaseOperation<T>(Future<T> Function() operation) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      return await operation();
    } catch (e) {
      print('Database operation error: $e');
      rethrow;
    }
  }
}
