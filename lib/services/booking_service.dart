import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getBookingStats(String userId) async {
    try {
      final bookingsRef = _database.child('bookings');
      final DataSnapshot snapshot = await bookingsRef
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists) {
        return _getEmptyStats();
      }

      final Map<dynamic, dynamic> bookings = 
          Map<dynamic, dynamic>.from(snapshot.value as Map);

      int completed = 0;
      int upcoming = 0;
      int cancelled = 0;
      int pending = 0;
      Map<String, dynamic>? ongoing;
      Map<String, dynamic>? pendingBooking;

      bookings.forEach((key, value) {
        final booking = Map<String, dynamic>.from(value);
        switch (booking['status']) {
          case 'completed':
            completed++;
            break;
          case 'upcoming':
            upcoming++;
            break;
          case 'cancelled':
            cancelled++;
            break;
          case 'ongoing':
            ongoing = booking;
            break;
          case 'pending':
            pending++;
            pendingBooking ??= booking;
            break;
        }
      });

      return {
        'completed': completed,
        'upcoming': upcoming,
        'cancelled': cancelled,
        'pending': pending,
        'ongoing': ongoing,
        'pendingBooking': pendingBooking,
      };
    } catch (e) {
      print('Error fetching booking stats: $e');
      return _getEmptyStats();
    }
  }

  // Add booking with improved error handling
  Future<void> addBooking(Map<String, dynamic> bookingData) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Validate required fields
      if (!bookingData.containsKey('servicePersonId') || 
          !bookingData.containsKey('amount')) {
        throw Exception('Missing required fields');
      }

      // Create new booking reference
      final newBookingRef = _database.child('bookings').push();
      final bookingId = newBookingRef.key!;

      // Add required fields with null safety
      final completeBookingData = {
        ...bookingData,
        'userId': currentUser.uid,
        'bookingId': bookingId,
        'status': bookingData['status'] ?? 'pending',
        'amount': bookingData['amount'] ?? 0,
        'timestamp': ServerValue.timestamp,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Create all updates in a single transaction
      final Map<String, dynamic> updates = {
        'bookings/$bookingId': completeBookingData,
        'user_bookings/${currentUser.uid}/$bookingId': {
          'status': completeBookingData['status'],
          'timestamp': completeBookingData['timestamp'],
        },
        'service_person_bookings/${bookingData['servicePersonId']}/$bookingId': {
          'status': completeBookingData['status'],
          'timestamp': completeBookingData['timestamp'],
        },
      };

      await _database.update(updates);
    } catch (e) {
      print('Error adding booking: $e');
      rethrow;
    }
  }

  // Update booking with proper checks
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // First check if user owns this booking
      final bookingSnapshot = await _database
          .child('bookings')
          .child(bookingId)
          .child('userId')
          .get();

      if (bookingSnapshot.value != currentUser.uid) {
        throw Exception('Unauthorized to update this booking');
      }

      await _database
          .child('bookings')
          .child(bookingId)
          .update({'status': status});
    } catch (e) {
      print('Error updating booking status: $e');
      rethrow;
    }
  }

  // Stream bookings with proper path
  Stream<DatabaseEvent> streamUserBookings(String userId) {
    return _database
        .child('user_bookings/$userId')
        .onValue;
  }

  // Get booking details with proper checks
  Future<Map<String, dynamic>?> getBooking(String bookingId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final DataSnapshot snapshot = 
          await _database.child('bookings/$bookingId').get();
      
      if (!snapshot.exists) return null;
      
      final bookingData = Map<String, dynamic>.from(snapshot.value as Map);
      
      // Check if user is authorized to view this booking
      if (bookingData['userId'] != currentUser.uid) {
        throw Exception('Unauthorized to view this booking');
      }
      
      return bookingData;
    } catch (e) {
      print('Error fetching booking: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> getActiveBookingStats(String uid) {
    // Listen to both bookings and user_bookings for real-time updates
    return _database
        .child('bookings')  // Changed from .ref().child() to just .child()
        .orderByChild('userId')
        .equalTo(uid)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;

      try {
        final Map<String, dynamic> bookings = Map<String, dynamic>.from(data as Map);
        
        // Filter out completed and cancelled bookings
        final activeBookings = Map.fromEntries(
          bookings.entries.where((entry) {
            final status = entry.value['status']?.toString().toLowerCase() ?? '';
            return status == 'pending' || 
                   status == 'on the way' || 
                   status == 'ongoing';
          })
        );

        return activeBookings.isNotEmpty ? activeBookings : null;
      } catch (e) {
        print('Error parsing booking stats: $e');
        return null;
      }
    });
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'completed': 0,
      'upcoming': 0,
      'cancelled': 0,
      'pending': 0,
      'ongoing': null,
      'pendingBooking': null,
    };
  }

  requestRefund({required String bookingId, required String reason}) {}

  getActiveBookings() {}
}
