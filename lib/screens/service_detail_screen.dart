import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fixr/screens/service_persons_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/service_model.dart';
import '../theme/app_theme.dart';
import '../utils/hero_tags.dart';

class ServiceDetailScreen extends StatefulWidget {
  final ServiceModel service;
  final bool isFavorite;
  final Function(bool) onFavoriteChanged;
  final String heroTagSource;

  const ServiceDetailScreen({
    super.key,
    required this.service,
    required this.isFavorite,
    required this.onFavoriteChanged,
    required this.heroTagSource,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  String? _userAddress;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .get();

        if (snapshot.exists) {
          final userData = snapshot.value as Map<dynamic, dynamic>;
          final address = userData['address'] as String?;
          if (address != null) {
            setState(() {
              _userAddress = address;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user address: $e');
    }
  }

  Future<void> _shareService(BuildContext context) async {
    try {
      final String shareUrl = 'https://fixr.app/service/${widget.service.id}';
      final String shareText = '''
🛠️ Check out this service on Fixr!

${widget.service.title}
💰 Price: ₹${widget.service.price}
⭐ Rating: ${widget.service.rating}

${widget.service.description}

Book now: $shareUrl
''';

      await Share.share(shareText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to share at this moment'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String? _extractMainLocation(String? address) {
    if (address == null) return null;
    // Convert address to lowercase for case-insensitive comparison
    final addressWords = address.toLowerCase().split(RegExp(r'[,\s]+'));
    // List of known zones
    final knownZones = ['rasakkapalayam', 'madurai']; // Add all your zones here
    
    // Find first matching zone in address
    return knownZones.firstWhere(
      (zone) => addressWords.contains(zone),
      orElse: () => '',
    );
  }

  void _navigateToServicePersons(BuildContext context, ServiceModel service) async {
    setState(() => _isLoading = true);
    
    try {
      final userZone = _extractMainLocation(_userAddress);
      
      await Future.delayed(const Duration(milliseconds: 500)); // Optional loading simulation
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServicePersonsScreen(
              categoryId: service.category,
              zone: userZone ?? '',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainLocation = _extractMainLocation(_userAddress);
    final bool isInServiceZone = mainLocation != null;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: HeroTags.getServiceImageTag(widget.service.id, widget.heroTagSource),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.service.image.isNotEmpty
                        ? Image.network(
                            widget.service.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 32,
                                    color: Colors.grey,
                                  ),
                                ),
                          )
                        : Container(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            child: Icon(
                              Icons.handyman,
                              size: 64,
                              color: AppTheme.primaryColor.withOpacity(0.5),
                            ),
                          ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite ? Colors.red : Colors.white,
                ),
                onPressed: () => widget.onFavoriteChanged(!widget.isFavorite),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _shareService(context),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.service.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.service.rating.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "₹${widget.service.totalCharge}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "(Service: ₹${widget.service.serviceCharge} + Travel: ₹${widget.service.travelCharge})",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'About this service',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.service.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow(
                    icon: Icons.access_time,
                    title: 'Duration',
                    value: widget.service.duration,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.star_outline,
                    title: 'Reviews',
                    value: '${widget.service.reviews} reviews',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.check_circle_outline,
                    title: 'Status',
                    value: widget.service.availability,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _navigateToServicePersons(context, widget.service),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(
                  Icons.handyman,
                  size: 20,
                  color: Colors.white,
                ),
              const SizedBox(width: 8),
              Text(
                _isLoading ? 'Loading...' : 'Book Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
