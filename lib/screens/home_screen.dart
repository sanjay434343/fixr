import 'dart:async';
import 'package:fixr/models/booking_model.dart';
import 'package:fixr/screens/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/services_repository.dart';
import '../services/database_helper.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../models/service_model.dart';
import 'category_services_screen.dart';
import 'search_results_screen.dart';
import '../theme/app_theme.dart';
import 'service_detail_screen.dart';
import 'my_bookings_screen.dart';
import '../widgets/custom_loader.dart';
import '../services/booking_service.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'services_screen.dart';
import '../widgets/service_card.dart';
import 'package:firebase_database/firebase_database.dart';
import 'profile_screen.dart';
import '../widgets/custom_app_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fixr/screens/fixr_bot_screen.dart';
import 'package:fixr/screens/easter_egg_screen.dart';

class HomeScreen extends StatefulWidget {
  String uid;

  HomeScreen({super.key, required this.uid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final LocalStorageService _storageService = LocalStorageService();
  final ServicesRepository _servicesRepo = ServicesRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final UserService _userService = UserService();
  final BookingService _bookingService = BookingService();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child('users');
  StreamSubscription<DatabaseEvent>? _userSubscription;
  bool _showSearchBar = true;
  bool _isSearchVisible = false;
  List<ServiceModel> _services = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  UserModel? _userData;
  Map<String, dynamic>? _bookingStats;

  // Add animation controller
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  final bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  int _titleTapCount = 0; // Add this variable

  // Add timer for tap counting
  Timer? _titleTapTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    
    // Check if we have a valid UID
    if (widget.uid.isEmpty) {
      _loadStoredUid();
    } else {
      _loadInitialData();
    }

    // Initialize animations
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
  }

  Future<void> _loadStoredUid() async {
    final storedUid = await _authService.getCurrentUserId();
    if (storedUid != null && mounted) {
      setState(() {
        widget.uid = storedUid; // Note: You'll need to make uid non-final in HomeScreen
      });
      _loadInitialData();
    } else {
      // Handle no stored UID - redirect to login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userService.getUserData(widget.uid);
      
      if (!mounted) return;

      if (userData != null) {
        setState(() => _userData = userData);
        
        // Update only the specific user's node
        await _userRef.child(widget.uid).update(userData.toJson());
      } else {
        final defaultUser = UserModel(
          uid: widget.uid,
          name: 'Guest User',
          email: '',
          phone: '',
          address: '',
          doornum: '',
          landmark: '',
          createdAt: DateTime.now(),
        );
        
        setState(() => _userData = defaultUser);
        await _userService.createUserData(widget.uid, defaultUser);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load user data')),
        );
      }
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Load user data first
      await _loadUserData();
      
      // Load services
      await _loadServices();
      
      // Setup realtime listener
      _setupUserListener();

      // Setup booking stats listener
      _bookingService.getActiveBookingStats(widget.uid).listen(
        (stats) {
          if (mounted) {
            setState(() => _bookingStats = stats);
          }
        },
        onError: (e) {
          debugPrint('Error loading booking stats: $e');
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error in initial data load: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupUserListener() {
    _userSubscription?.cancel();
    _userSubscription = _userRef.child(widget.uid).onValue.listen(
      (event) {
        if (!mounted) return;
        
        try {
          if (event.snapshot.value != null) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final DateTime createdAt = DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();
            
            setState(() {
              _userData = UserModel(
                uid: widget.uid,
                name: data['name'] ?? 'Guest User',
                email: data['email'] ?? '',
                phone: data['phone'] ?? '',
                address: data['address'] ?? '',
                doornum: data['doornum'] ?? '',
                landmark: data['landmark'] ?? '',
                createdAt: createdAt,
              );
            });
          }
        } catch (e) {
          debugPrint('Error parsing user data from listener: $e');
          // Force reload data if parsing fails
          _loadInitialData();
        }
      },
      onError: (error) {
        debugPrint('Error in user listener: $error');
        // Force reload data on error
        _loadInitialData();
      },
    );
  }

  @override
  void dispose() {
    _titleTapTimer?.cancel();
    _userSubscription?.cancel();
    _progressController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 10 && _showSearchBar) {
      setState(() {
        _showSearchBar = false;
      });
    } else if (_scrollController.offset <= 10 && !_showSearchBar) {
      setState(() {
        _showSearchBar = true;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // Complete sign out that clears all preferences
    await _authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _loadServices() async {
    try {
      setState(() => _isLoading = true);
      final services = await _servicesRepo.getServices();
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading services: $e');
    }
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _userData?.name ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty && newName != _userData?.name) {
        try {
          // Update both Firestore and Realtime Database
          final success = await _userService.updateUserName(widget.uid, newName);
          await _userRef.child(widget.uid).update({'name': newName});
          
          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update name')),
            );
          }
        } catch (e) {
          print('Error updating name: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update name')),
            );
          }
        }
      }
    }
  }

  Future<void> _showEditAddressDialog() async {
    final TextEditingController doornumController = TextEditingController(
      text: _userData?.doornum ?? '',
    );
    final TextEditingController addressController = TextEditingController(
      text: _userData?.address ?? '',
    );
    final TextEditingController landmarkController = TextEditingController(
      text: _userData?.landmark ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: doornumController,
              decoration: const InputDecoration(
                labelText: 'Door Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: landmarkController,
              decoration: const InputDecoration(
                labelText: 'Landmark',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final updates = {
        'doornum': doornumController.text.trim(),
        'address': addressController.text.trim(),
        'landmark': landmarkController.text.trim(),
      };

      final success = await _userService.updateUserProfile(widget.uid, updates);
      if (success) {
        _loadUserData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update address details')),
          );
        }
      }
    }
  }

  void _showSearchSheet() {
    final theme = Theme.of(context);
    TextEditingController searchController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => FutureBuilder<List<String>>(
            future: _dbHelper.getSearchHistory(),
            builder: (context, snapshot) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Handle bar with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            theme.cardColor,
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.dividerColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Search Services',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        elevation: 0,
                        borderRadius: BorderRadius.circular(30),
                        color: theme.cardColor,
                        child: TextField(
                          controller: searchController,
                          autofocus: true,
                          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'What service are you looking for?',
                            hintStyle: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                              fontSize: 15,
                            ),
                            filled: true,
                            fillColor: theme.brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppTheme.primaryColor.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                color: theme.dividerColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(
                                color: theme.dividerColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryColor,
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 20,
                                color: theme.iconTheme.color?.withOpacity(0.5),
                              ),
                              onPressed: () => searchController.clear(),
                            ),
                          ),
                          onSubmitted: (value) async {
                            if (value.trim().isEmpty) return;
                            final query = value.trim();
                            
                            // Store search and close sheet
                            await _dbHelper.insertSearch(query);
                            Navigator.pop(context);

                            // Navigate to search results immediately
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchResultsScreen(
                                  query: query,
                                  // Pass refresh callback to update home screen services
                                  onSearchComplete: () => _loadServices(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (snapshot.hasData && snapshot.data!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Searches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () async {
                                await _dbHelper.clearSearchHistory();
                                if (!mounted) return;
                                Navigator.pop(context);
                                _showSearchSheet();
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Clear'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red[400],
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Recent searches list
                    if (snapshot.hasData && snapshot.data!.isNotEmpty)
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            final query = snapshot.data![index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(15),
                                elevation: 0.5,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(15),
                                  onTap: () async {
                                    // Store the clicked search
                                    await _dbHelper.insertSearch(query);
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SearchResultsScreen(
                                          query: query,
                                          onSearchComplete: () => _loadServices(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.history,
                                            color: AppTheme.primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            query,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: theme.textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.search,
                                          color: theme.iconTheme.color?.withOpacity(0.5),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    // Empty state remains same
                    if (snapshot.hasData && snapshot.data!.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: theme.iconTheme.color?.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recent searches',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
    });
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryServicesScreen(category: category),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // If not on home screen, navigate to home
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    
    // If on home screen, show exit dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.exit_to_app, color: Colors.red[400], size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Exit App'),
          ],
        ),
        content: const Text('Are you sure you want to exit?'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    
    return shouldExit ?? false;
  }

  Widget _buildAnimatedCounter(IconData icon, Color color, int count) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 800),
      builder: (context, int value, child) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQRDialog(BuildContext context) {
    // Get the oldest active booking
    if (_bookingStats == null || _bookingStats!.isEmpty) return;
    
    final oldestBooking = _bookingStats!.entries
      .where((entry) => entry.value['status'] != 'completed')
      .reduce((a, b) => 
        (a.value['bookingDate'] as int) < (b.value['bookingDate'] as int) ? a : b);

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Booking QR Code',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Transform.scale(
                                scale: value,
                                child: QrImageView(
                                  data: oldestBooking.key,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  gapless: false,
                                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code,
                                    size: 16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    oldestBooking.key.substring(0, 8),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button with fade animation
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Opacity(
                          opacity: value,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).shadowColor.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveBookingCard(BookingModel booking) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      elevation: 8,
      shadowColor: theme.shadowColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToBookingDetails(booking),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.bookmark, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Active Booking',
                    style: TextStyle(
                      color: theme.textTheme.titleMedium?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      booking.status,
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: TextStyle(
                          color: theme.textTheme.titleLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.formattedDate,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          booking.timeSlot,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  void _navigateToBookingDetails(BookingModel booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(booking: booking),
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await _loadServices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Updated with latest services'),
                ],
              ),
              duration: Duration(seconds: 2),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      },
      child: _isLoading 
        ? const CustomLoader()
        : CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Enhanced Welcome Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.15),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeSection(),
                      const SizedBox(height: 24),
                      if (_bookingStats != null) _buildEnhancedBookingProgress(),
                    ],
                  ),
                ),
              ),

              // Quick Actions Section
              SliverToBoxAdapter(
                child: _buildQuickActionsGrid(),
              ),

              // Enhanced Categories Section
              SliverToBoxAdapter(
                child: _buildEnhancedCategories(),
              ),

              // Popular Services Section with Animation
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnimatedSectionHeader(
                        'Popular Services',
                        'Highly rated services by users',
                        Icons.star_outline,
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced Services List
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: _services.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmptyStateWithAnimation(),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildEnhancedServiceCard(_services[index]),
                          childCount: _services.length,
                        ),
                      ),
              ),]
          ),
    );
  }

  Widget _buildWelcomeSection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getGreetingMessage(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 0.5,
                        child: const Text(
                          '👋',
                          style: TextStyle(fontSize: 20),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _userData?.name.split(' ')[0] ?? 'Guest',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildStatsCounter(),
      ],
    );
  }

  Widget _buildStatsCounter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_bookingStats != null)
          _buildAnimatedCounter(
            Icons.handyman,
            Colors.green[400]!,
            _getActiveBookingsCount(),
          ),
      ],
    );
  }

  Widget _buildEnhancedBookingProgress() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_bookingStats == null || _bookingStats!.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark 
                ? Colors.grey[800]! 
                : AppTheme.primaryColor.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tips_and_updates,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Quick Tip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '"Make your home perfect ',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                  TextSpan(
                    text: 'one service at a time',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '"',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Book your first service today and experience the convenience of professional home maintenance.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentIndex = 1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.home_repair_service, size: 18),
              label: const Text('Explore Our Services'),
            ),
          ],
        ),
      );
    }

    // Show booking progress if there's an active booking
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Booking Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showQRDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 18,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Show QR',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildServiceProgress(_getCurrentBookingStatus()),
        ],
      ),
    );
  }

  String _getCurrentBookingStatus() {
    if (_bookingStats == null || _bookingStats!.isEmpty) return 'pending';
    
    // Get the oldest active booking
    final oldestBooking = _bookingStats!.entries
      .where((entry) => entry.value['status'] != 'completed')
      .reduce((a, b) => 
        (a.value['bookingDate'] as int) < (b.value['bookingDate'] as int) ? a : b);

    return oldestBooking.value['status'] ?? 'pending';
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedSectionHeader(
            'Quick Actions',
            'Access frequently used features',
            Icons.flash_on_outlined,
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildQuickActionCard(
                'All Services',
                Icons.miscellaneous_services_outlined,
                Colors.green,
                () => setState(() => _currentIndex = 1),
              ),
              _buildQuickActionCard(
                'My Bookings',
                Icons.calendar_today_outlined,
                Colors.blue,
                () => setState(() => _currentIndex = 2),
              ),
              _buildQuickActionCard(
                'Search',
                Icons.search,
                Colors.orange,
                _showSearchSheet,
              ),
              _buildQuickActionCard(
                'Profile',
                Icons.person_outline,
                Colors.purple,
                () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title, 
    IconData icon, 
    MaterialColor color, 
    VoidCallback onTap, 
    {String? badge}
  ) {
    return Material(
      elevation: 2,
      shadowColor: color.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color[50]!, color[100]!],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color[200]!, width: 1),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color[700], size: 28),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color[800],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) const SizedBox(width: 24),
                      ],
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActiveBookingsDialog() async {
    if (_bookingStats == null || _getActiveBookingsCount() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active bookings at the moment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.engineering, color: Colors.green[700]),
            ),
            const SizedBox(width: 12),
            const Text('Active Bookings'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bookingStats!.entries
                .where((entry) => 
                    entry.value['status'] != 'completed' && 
                    entry.value['status'] != 'cancelled')
                .map((entry) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(entry.value['status'] as String),
                              color: Colors.green[700],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value['serviceName'] ?? 'Service',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  entry.value['status'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _currentIndex = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('View All Bookings'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_outlined;
      case 'on the way':
        return Icons.directions_run;
      case 'ongoing':
        return Icons.handyman;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _buildAnimatedSectionHeader(String title, String subtitle, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyStateWithAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handyman_outlined, 
            size: 64, 
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No services available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadServices,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedServiceCard(ServiceModel service) {
    return ServiceCard(
      service: service,
      heroTagSource: 'home',
      isFavorite: false, // Add this
      onFavoriteChanged: (_) {}, // Add this empty callback
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceDetailScreen(
            service: service,
            heroTagSource: 'home',
            isFavorite: false, // Add this
            onFavoriteChanged: (_) {}, // Add this empty callback
          ),
        ),
      ),
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  int _getActiveBookingsCount() {
    if (_bookingStats == null) return 0;
    
    return _bookingStats!.entries
      .where((entry) => 
        entry.value is Map && 
        entry.value['status'] != null &&
        (entry.value['status'] as String).toLowerCase() != 'completed')
      .length;
  }

  Widget _buildServiceProgress(String currentStatus) {
    final statusMap = {
      'pending': 0,
      'on the way': 1,
      'ongoing': 2,
      'completed': 3
    };
    
    final statuses = ['pending', 'on the way', 'ongoing', 'completed'];
    final currentIdx = statusMap[currentStatus.toLowerCase()] ?? 0;
    
    _progressController.forward(from: 0);

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Row(
                children: statuses.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final status = entry.value;
                  final isActive = idx <= currentIdx;
                  final isCurrent = idx == currentIdx;
                  final isLast = idx == statuses.length - 1;
                  
                  final progress = _progressAnimation.value;
                  final shouldShowProgress = idx <= currentIdx;
                  final lineProgress = shouldShowProgress ? progress : 0.0;

                  final lineColor = isActive 
                      ? Color.lerp(Colors.grey[300], AppTheme.primaryColor, lineProgress)!
                      : Colors.grey[300]!;

                  return Expanded(
                    child: TimelineTile(
                      axis: TimelineAxis.horizontal,
                      alignment: TimelineAlign.center,
                      isFirst: idx == 0,
                      isLast: isLast,
                      beforeLineStyle: LineStyle(
                        color: lineColor,
                        thickness: 2,
                      ),
                      afterLineStyle: LineStyle(
                        color: idx < currentIdx ? lineColor : Colors.grey[300]!,
                        thickness: 2,
                      ),
                      indicatorStyle: IndicatorStyle(
                        width: 30,
                        height: 30,
                        indicator: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(
                            begin: 0,
                            end: isActive ? 1.0 : 0.0,
                          ),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: 0.8 + (value * 0.2),
                              child: _buildIndicator(status, isActive && value == 1.0, isCurrent),
                            );
                          },
                        ),
                      ),
                      endChild: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isCurrent ? AppTheme.primaryColor 
                                 : isActive ? Colors.black87 
                                 : Colors.grey,
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.w700 
                                    : isActive ? FontWeight.w600 
                                    : FontWeight.normal,
                          ),
                          child: Text(
                            _getStatusLabel(status),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(String status, bool isActive, bool isCurrent) {
    IconData getStatusIcon() {
      switch (status.toLowerCase()) {
        case 'pending':
          return Icons.pending;
        case 'on the way':
          return Icons.directions_run;
        case 'ongoing':
          return Icons.handyman;
        case 'completed':
          return Icons.check_circle;
        default:
          return Icons.circle;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? AppTheme.primaryColor 
             : isActive ? Colors.white 
             : Colors.grey[300],
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? AppTheme.primaryColor : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: isCurrent ? [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Center(
        child: Icon(
          getStatusIcon(),
          size: 16,
          color: isCurrent ? Colors.white 
               : isActive ? AppTheme.primaryColor 
               : Colors.white,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Booking\nPending';
      case 'on the way':
        return 'On The\nWay';
      case 'ongoing':
        return 'Service\nOngoing';
      case 'completed':
        return 'Service\nComplete';
      default:
        return status;
    }
  }

  Widget _buildCategoryItem(String title, IconData icon, MaterialColor color) {
    return GestureDetector(
      onTap: () => _navigateToCategory(title.toLowerCase()),
      child: Container(
        width: 90, // Reduced width
        height: 90, // Fixed height
        margin: const EdgeInsets.only(right: 12),
        child: Material(
          elevation: 2,
          shadowColor: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8), // Reduced padding
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color[50]!, color[100]!],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color[200]!, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Changed to min
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color[700], size: 24), // Reduced size
                ),
                const SizedBox(height: 6), // Reduced spacing
                Flexible( // Added Flexible
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12, // Reduced font size
                      fontWeight: FontWeight.bold,
                      color: color[800],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1, // Limit to single line
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 26, // Default larger size
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12), // Increased padding
            child: Icon(
              icon,
              size: size,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedCategories() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedSectionHeader(
            'Categories',
            'Browse services by category',
            Icons.category_outlined,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildCategoryItem('Plumbing', Icons.plumbing, Colors.blue),
                _buildCategoryItem('Cleaning', Icons.cleaning_services, Colors.green),
                _buildCategoryItem('Electrical', Icons.electrical_services, Colors.orange),
                _buildCategoryItem('Painting', Icons.format_paint, Colors.purple),
                _buildCategoryItem('Carpentry', Icons.carpenter, Colors.brown),
                _buildCategoryItem('Gardening', Icons.yard, Colors.teal),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleTitleTap() {
    _titleTapCount++;
    
    // Reset timer if exists
    _titleTapTimer?.cancel();
    
    // Create new timer
    _titleTapTimer = Timer(const Duration(milliseconds: 500), () {
      _titleTapCount = 0; // Reset count after delay
    });

    if (_titleTapCount == 3) {
      _titleTapCount = 0;
      _titleTapTimer?.cancel();
      HapticFeedback.mediumImpact(); // Add haptic feedback
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EasterEggScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          appBar: CustomAppBar(
            title: 'Fixr',
            showSearch: false,
            searchController: _searchController,
            onSearchTap: () {
              _showSearchSheet();
            },
            onTitleTap: _handleTitleTap, // Update this line
            onSearchSubmitted: null,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[900] 
                : Colors.white,
            elevation: 0,
            indicatorColor: AppTheme.primaryColor.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1
            ),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              _buildNavDestination(0, Icons.home_outlined, Icons.home, 'Home'),
              _buildNavDestination(1, Icons.handyman_outlined, Icons.handyman, 'Services'),
              _buildNavDestination(2, Icons.calendar_today_outlined, Icons.calendar_today, 'Bookings'),
              _buildNavDestination(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Fixr AI'),
              _buildNavDestination(4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(),
              const ServicesScreen(),
              const MyBookingsScreen(),
              const FixrBotScreen(),
              ProfileScreen(uid: widget.uid),
            ],
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination(
    int index, 
    IconData icon, 
    IconData selectedIcon, 
    String label,
  ) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return NavigationDestination(
      icon: Icon(
        icon,
        color: isSelected 
            ? AppTheme.primaryColor 
            : isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      selectedIcon: Icon(
        selectedIcon, 
        color: AppTheme.primaryColor,
      ),
      label: label,
    );
  }
}

