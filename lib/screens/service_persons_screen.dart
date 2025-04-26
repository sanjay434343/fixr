import 'package:firebase_database/firebase_database.dart';
import 'package:fixr/widgets/booking_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';

class ServicePersonsScreen extends StatefulWidget {
  final String categoryId;
  final String zone;

  const ServicePersonsScreen({
    super.key,
    required this.categoryId,
    this.zone = '',
  });

  @override
  State<ServicePersonsScreen> createState() => _ServicePersonsScreenState();
}

class _ServicePersonsScreenState extends State<ServicePersonsScreen> {
  static const double APP_SERVICE_CHARGE = 50.0; // Changed to double
  double? _defaultServiceCharge; // Changed to double
  double? _defaultTravelCharge; // Changed to double

  double _calculateStringSimilarity(String str1, String str2) {
    str1 = str1.toLowerCase();
    str2 = str2.toLowerCase();
    
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;
    
    int matchingChars = 0;
    for (int i = 0; i < str1.length && i < str2.length; i++) {
      if (str1[i] == str2[i]) matchingChars++;
    }
    
    return matchingChars / (str1.length > str2.length ? str1.length : str2.length);
  }

  Future<void> _storeUserZone(String zone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .update({
          'extractedZone': zone.toLowerCase(),
          'lastUpdated': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error storing user zone: $e');
    }
  }

  Future<bool> _storeBookingData(Map<String, dynamic> servicePerson, DateTime bookingDateTime) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .get();

      if (!userSnapshot.exists) {
        throw Exception('User data not found');
      }

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      final bookingId = const Uuid().v4();

      // Create booking data with exact structure needed
      final bookingData = {
        'id': bookingId,
        'userId': user.uid,
        'userName': userData['name'] ?? '',
        'userPhone': userData['phone'] ?? '',
        'servicePersonId': servicePerson['id'],
        'serviceId': widget.categoryId,
        'serviceName': widget.categoryId,
        'amount': servicePerson['totalCharge'],
        'status': 'pending',
        'bookingDate': DateTime.now().millisecondsSinceEpoch,
        'serviceDate': bookingDateTime.millisecondsSinceEpoch,
        'transactionId': 'TXN${DateTime.now().millisecondsSinceEpoch}',
      };

      // Store only in main bookings node
      await FirebaseDatabase.instance
          .ref()
          .child('bookings')
          .child(bookingId)
          .set(bookingData);

      return true;
    } catch (e) {
      print('Error storing booking data: $e');
      return false;
    }
  }

  Stream<List<Map<String, dynamic>>> _getServicePersons() {
    return FirebaseDatabase.instance
        .ref()
        .child('servicePersons')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      try {
        final Map<dynamic, dynamic> dataMap = data as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> persons = [];
        final userZone = widget.zone.toLowerCase();
        final serviceCategory = widget.categoryId.toLowerCase();
        
        FirebaseDatabase.instance
            .ref()
            .child('services')
            .child(serviceCategory)
            .get()
            .then((categorySnapshot) {
          if (categorySnapshot.exists) {
            final categoryData = categorySnapshot.value as Map<dynamic, dynamic>;
            final defaultServiceCharge = (categoryData['serviceCharge'] ?? 0).toDouble();
            final defaultTravelCharge = (categoryData['travelCharge'] ?? 0).toDouble();
            
            if (mounted) {
              setState(() {
                _defaultServiceCharge = defaultServiceCharge;
                _defaultTravelCharge = defaultTravelCharge;
              });
            }
          }
        });
        
        dataMap.forEach((key, value) {
          if (value is Map) {
            final person = Map<String, dynamic>.from(value);
            final personZone = (person['zone'] as String?)?.toLowerCase() ?? '';
            final services = person['services'] as Map?;
            
            final double serviceCharge = double.parse((person['serviceCharge'] ?? _defaultServiceCharge ?? 0).toString());
            final double travelCharge = double.parse((person['travelCharge'] ?? _defaultTravelCharge ?? 0).toString());
            
            double similarity = _calculateStringSimilarity(personZone, userZone);
            bool hasService = services?[serviceCategory] == true;
            
            if (similarity >= 0.8 && hasService) {
              final double totalCharge = serviceCharge + travelCharge + APP_SERVICE_CHARGE;
              
              persons.add({
                'id': key,
                'name': person['name'] ?? '',
                'phone': person['phone'] ?? '',
                'experience': person['experience'] ?? '',
                'rating': (person['rating'] ?? 0.0).toDouble(),
                'zone': person['zone'] ?? '',
                'profile': person['profile'] ?? '',
                'services': services ?? {},
                'similarity': similarity,
                'serviceCharge': serviceCharge,
                'travelCharge': travelCharge,
                'appCharge': APP_SERVICE_CHARGE,
                'totalCharge': totalCharge,
              });
            }
          }
        });

        persons.sort((a, b) {
          if ((a['similarity'] as double) != (b['similarity'] as double)) {
            return (b['similarity'] as double).compareTo(a['similarity'] as double);
          }
          return (b['rating'] as double).compareTo(a['rating'] as double);
        });
        
        return persons;
      } catch (e) {
        print('Error parsing service persons: $e');
        return [];
      }
    });
  }

  void _launchPhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Could not launch phone call: $e');
    }
  }

  void _launchWhatsApp(String phoneNumber) async {
    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final whatsappUrl = "whatsapp://send?phone=+91$phoneNumber";
    try {
      await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Could not launch WhatsApp: $e');
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Transform.scale(
          scale: value.clamp(0.0, 1.0),  // Clamp scale value
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'preview_$imageUrl',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 20 * value.clamp(0.0, 1.0)),  // Clamp offset value
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),  // Clamp opacity value
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String? imageUrl, [String name = '']) {
    return GestureDetector(
      onTap: imageUrl?.isNotEmpty == true
          ? () => _showImagePreview(context, imageUrl!, name)
          : null,
      child: CircleAvatar(
        radius: 35,
        backgroundColor: Colors.transparent,
        child: imageUrl?.isNotEmpty == true
            ? ClipOval(
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  width: 70,
                  height: 70,
                  errorBuilder: (context, error, stackTrace) => Text(
                    'N/A',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ),
              )
            : Text(
                'N/A',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
      ),
    );
  }

  Widget _buildServiceTag(String service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Text(
        service,
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildChargesSection(Map<String, dynamic> person) {
    final double serviceCharge = person['serviceCharge']; // Changed to double
    final double travelCharge = person['travelCharge']; // Changed to double
    final double appCharge = APP_SERVICE_CHARGE; // Changed to double
    final double totalCharge = person['totalCharge']; // Changed to double

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Charges',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '₹$totalCharge',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Charge: ₹$serviceCharge',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Travel Charge: ₹$travelCharge',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              Text(
                'App Fee: ₹$appCharge',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargesDisplay(Map<String, dynamic> person) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.currency_rupee, 
            size: 14,
            color: Colors.green[700],
          ),
          Text(
            '${person['totalCharge']}',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (person['serviceCharge'] > 0 || person['travelCharge'] > 0)
            Text(
              ' (${person['serviceCharge']} + ${person['travelCharge']} + $APP_SERVICE_CHARGE)',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChargeItem(String label, double amount, IconData icon) { // Changed parameter type to double
    // Change travel icon when used
    final actualIcon = label == 'Travel' ? Icons.motorcycle : icon;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Icon(
            actualIcon,
            size: 16,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '₹$amount',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showBookingSheet(BuildContext context, Map<String, dynamic> servicePerson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BookingBottomSheet(
          amount: servicePerson['totalCharge'].toDouble(),
          servicePersonId: servicePerson['id'],
          serviceId: widget.categoryId,
          serviceName: widget.categoryId,
          charges: {
            'serviceCharge': servicePerson['serviceCharge'],
            'travelCharge': servicePerson['travelCharge'],
            'appCharge': APP_SERVICE_CHARGE,
          },
        ),
      ),
    ).then((selectedDateTime) async {
      if (selectedDateTime != null) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        final success = await _storeBookingData(servicePerson, selectedDateTime);
        
        // Hide loading indicator
        Navigator.pop(context);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking successful!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to book. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service Providers'),
            Text(
              'in ${widget.zone}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getServicePersons(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final persons = snapshot.data!;
          if (persons.isEmpty) {
            return const Center(
              child: Text('No service providers available'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: persons.length,
            itemBuilder: (context, index) {
              final person = persons[index];
              return TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) => Transform.scale(
                  scale: 0.95 + (0.05 * value),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.dividerColor,
                        width: 1.5,
                      ),
                    ),
                    elevation: 2,
                    color: theme.cardColor,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.cardColor,
                            Theme.of(context).brightness == Brightness.dark
                                ? theme.cardColor
                                : Colors.grey.shade50,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Hero(
                                      tag: 'profile_${person['id']}',
                                      child: Container(
                                        width: 70,    // Increased size
                                        height: 70,   // Increased size
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: Colors.transparent, // Remove background
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: _buildProfileImage(
                                            person['profile'],
                                            person['name'],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.work_outline,
                                                      size: 12,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${person['experience']}',
                                                      style: TextStyle(
                                                        color: AppTheme.primaryColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildServiceTag(widget.categoryId),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                        size: 16,
                                        color: Colors.amber[700],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        person['rating'].toString(),
                                        style: TextStyle(
                                          color: Colors.amber[900],
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '₹${person['totalCharge']}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildChargeItem(
                                      'Service',
                                      person['serviceCharge'],
                                      Icons.home_repair_service,
                                    ),
                                    _buildChargeItem(
                                      'Travel',
                                      person['travelCharge'],
                                      Icons.motorcycle,
                                    ),
                                    _buildChargeItem(
                                      'App Fee',
                                      APP_SERVICE_CHARGE,
                                      Icons.apps,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: ElevatedButton(
                              onPressed: () => _showBookingSheet(context, person),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.calendar_today, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Book Now',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
