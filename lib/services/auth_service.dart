import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/storage_keys.dart';
import 'local_storage_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance;
  final LocalStorageService _storage = LocalStorageService();

  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get isAuthenticated => _auth.currentUser != null;

  Future<UserCredential> signUp(String email, String password, Map<String, dynamic> userData) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Send email verification
        await userCredential.user!.sendEmailVerification();
        
        // Save user data
        await _database.ref().child('users/${userCredential.user!.uid}').set(userData);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        await _storage.writeString(StorageKeys.uid, user.uid);
        await _storage.writeBool(StorageKeys.isLoggedIn, true);
        return user.uid;
      }
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setString('password', password);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('rememberMe', true);
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    
    if (!rememberMe) {
      return {'email': null, 'password': null};
    }
    
    return {
      'email': prefs.getString('email'),
      'password': prefs.getString('password'),
    };
  }

  Future<bool> autoLogin() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Wait for auth state to propagate
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Enable syncing for user-specific data
        final userRef = _database.ref().child('users').child(user.uid);
        final bookingsRef = _database.ref().child('bookings').orderByChild('userId').equalTo(user.uid);
        
        await Future.wait([
          userRef.keepSynced(true),
          bookingsRef.keepSynced(true),
        ]);
        
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      
      // Only attempt auto-login if both flags are true
      if (!isLoggedIn || !rememberMe) {
        return false;
      }
      
      final storedEmail = prefs.getString('email');
      final storedPassword = prefs.getString('password');

      // Check if we have stored credentials
      if (storedEmail == null || storedPassword == null) {
        return false;
      }

      // Attempt login with stored credentials
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: storedEmail,
        password: storedPassword,
      );

      return userCredential.user != null;
    } catch (e) {
      print('Auto login error: $e');
      return false;
    }
  }

  // Add method to get user data safely
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      if (_auth.currentUser == null) return null;
      
      final snapshot = await _database.ref()
        .child('users')
        .child(uid)
        .once();
        
      if (snapshot.snapshot.value == null) return null;
      
      return Map<String, dynamic>.from(snapshot.snapshot.value as Map);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Add method to watch user data changes
  Stream<DatabaseEvent> watchUserData(String uid) {
    return _database.ref()
      .child('users')
      .child(uid)
      .onValue;
  }

  // Clear only authentication state but keep remember me preference
  Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final email = prefs.getString('email');
    final password = prefs.getString('password');
    
    await prefs.clear();
    
    // If remember me was enabled, preserve those settings
    if (rememberMe) {
      await prefs.setBool('rememberMe', true);
      if (email != null) await prefs.setString('email', email);
      if (password != null) await prefs.setString('password', password);
    }
  }

  Future<void> signOut() async {
    try {
      final uid = currentUser?.uid;
      if (uid != null) {
        // Disable sync for user data
        await _database.ref()
          .child('users')
          .child(uid)
          .keepSynced(false);
      }
      
      // Clear stored login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      
      await _auth.signOut();
      await _storage.remove(StorageKeys.uid);
      await _storage.remove(StorageKeys.isLoggedIn);
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  // Check if user is logged in using both Firebase and SharedPreferences
  Future<bool> isUserLoggedIn() async {
    if (_auth.currentUser != null) {
      return true;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    return isLoggedIn;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw 'No user logged in';
    
    // Create credentials with current password
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    
    try {
      // Reauthenticate user
      await user.reauthenticateWithCredential(credential);
      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Current password is incorrect';
      }
      throw e.message ?? 'An error occurred';
    }
  }

  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      return e.message ?? 'An unknown error occurred';
    }
    return 'An unknown error occurred';
  }

  Future<String?> getCurrentUserId() async {
    return await _storage.getString(StorageKeys.uid);
  }

  updateUserData(String uid, Map<String, String?> map) {}

  getCurrentUser() {}
}
