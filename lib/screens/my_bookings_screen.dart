import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';
import './booking_detail_screen.dart';
import '../widgets/custom_loader.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _database = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> _fetchUserDetails(String userId) async {
    final snapshot = await _database.ref().child('users').child(userId).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  Future<Map<String, dynamic>> _fetchServiceDetails(String serviceId) async {
    final snapshot = await _database.ref().child('services').child(serviceId).get();
    if (snapshot.exists) {
      return Map<String, dynamic>.from(snapshot.value as Map);
    }
    return {};
  }

  Stream<List<Map<String, dynamic>>> _getBookings() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _database
        .ref()
        .child('bookings')
        .orderByChild('userId')
        .equalTo(user.uid)
        .onValue
        .asyncMap((event) async {
      final data = event.snapshot.value;
      if (data == null) return [];

      try {
        final Map<dynamic, dynamic> dataMap = data as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> bookings = [];
        
        for (var entry in dataMap.entries) {
          if (entry.value is Map) {
            final booking = Map<String, dynamic>.from(entry.value as Map);
            booking['id'] = entry.key;
            
            // Fetch user details
            final userDetails = await _fetchUserDetails(booking['userId']);
            // Fetch service details
            final serviceDetails = await _fetchServiceDetails(booking['serviceId']);
            
            // Merge all details
            booking.addAll({
              'doorNumber': userDetails['doornum'] ?? '',
              'address': userDetails['address'] ?? '',
              'landmark': userDetails['landmark'] ?? '',
              'userName': userDetails['name'] ?? '',
              'userPhone': userDetails['phone'] ?? '',
              'serviceCharge': serviceDetails['serviceCharge'] ?? 0,
              'travelCharge': serviceDetails['travelCharge'] ?? 0,
              'appCharge': serviceDetails['appCharge'] ?? 0,
            });
            
            bookings.add(booking);
          }
        }

        // Sort by booking date (most recent first)
        bookings.sort((a, b) => (b['bookingDate'] as int)
            .compareTo(a['bookingDate'] as int));
        
        return bookings;
      } catch (e) {
        print('Error parsing bookings: $e');
        return [];
      }
    });
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final theme = Theme.of(context);
    final serviceDate = DateTime.fromMillisecondsSinceEpoch(booking['serviceDate']);
    final timeSlot = booking['timeSlot'] ?? 'Not specified';
    final amount = booking['amount']?.toString() ?? 'Not specified';
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (booking['status'].toString().toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'on the way':
        statusColor = Colors.blue;
        statusIcon = Icons.directions_run;
        statusText = 'On The Way';
        break;
      case 'ongoing':
        statusColor = Colors.green;
        statusIcon = Icons.handyman;
        statusText = 'In Progress';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor,
            theme.brightness == Brightness.dark 
                ? theme.cardColor 
                : Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          // Convert booking map to BookingModel
          final bookingModel = BookingModel(
            id: booking['id'],
            userId: booking['userId'],
            userName: booking['userName'] ?? '',
            userPhone: booking['userPhone'] ?? '',
            servicePersonId: booking['servicePersonId'] ?? '',
            serviceId: booking['serviceId'] ?? '',
            serviceName: booking['serviceName'],
            serviceDate: booking['serviceDate'],
            status: booking['status'],
            serviceCharge: (booking['serviceCharge'] ?? booking['amount']).toDouble(),
            travelCharge: (booking['travelCharge'] ?? 0).toDouble(),
            totalAmount: (booking['amount'] ?? 0).toDouble(),
            doorNumber: booking['doorNumber'] ?? '',
            address: booking['address'] ?? '',
            landmark: booking['landmark'] ?? '',
            timeSlot: DateFormat('hh:mm a').format(
              DateTime.fromMillisecondsSinceEpoch(booking['serviceDate'])
            ),
            bookingDate: booking['bookingDate'] ?? DateTime.now().millisecondsSinceEpoch,
            transactionId: booking['transactionId'] ?? '',
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(booking: bookingModel),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    amount != 'Not specified' ? '₹$amount' : amount,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                booking['serviceName'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(serviceDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeSlot,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${booking['doorNumber'] ?? ''}, ${booking['address'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (booking['landmark']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 26),
                        child: Text(
                          'Landmark: ${booking['landmark']}',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BOOKING ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking['id'].toString().substring(0, 8)}...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: null,
                    icon: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(
                      'View Details',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBookings() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: AppTheme.primaryColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Bookings Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start exploring our services\nand book your first appointment',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/service-providers',
                arguments: {'category': null, 'searchQuery': null},
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('Explore Services'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getBookings(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const CustomLoader();
            }

            final bookings = snapshot.data!;
            
            if (bookings.isEmpty) {
              return _buildEmptyBookings();
            }

            return ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) => _buildBookingCard(bookings[index]),
            );
          },
        ),
      ),
    );
  }
}
