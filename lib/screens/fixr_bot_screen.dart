import 'package:flutter/material.dart';
import 'package:fixr/theme/app_theme.dart';
import '../services/booking_service.dart';
import '../services/user_service.dart';
import '../models/booking_model.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';

class FixrBotScreen extends StatefulWidget {
  const FixrBotScreen({Key? key}) : super(key: key);

  @override
  State<FixrBotScreen> createState() => _FixrBotScreenState();
}

class _FixrBotScreenState extends State<FixrBotScreen> {
  final ScrollController _scrollController = ScrollController();
  final BookingService _bookingService = BookingService();
  final UserService _userService = UserService();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  String? _currentUid;
  Map<String, dynamic>? _userData;
  bool _awaitingNumericInput = false;
  String _currentAction = '';

  List<Map<String, dynamic>> messages = [];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _currentUid = _auth.currentUser?.uid;
    if (_currentUid != null) {
      await _loadUserData();
    }
    _showWelcomeMessage();
  }

  Future<void> _loadUserData() async {
    try {
      final snapshot = await _database.child('users/$_currentUid').get();
      if (snapshot.exists) {
        setState(() => _userData = Map<String, dynamic>.from(snapshot.value as Map));
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _showWelcomeMessage() {
    final userName = _userData?['name'] ?? 'there';
    final greeting = TimeOfDay.now().hour < 12 ? 'Good morning' : 
                    TimeOfDay.now().hour < 17 ? 'Good afternoon' : 'Good evening';
    
    _addBotMessage(
      "$greeting, $userName!\n"
      "How can I assist you today?\n\n"
      "1. Profile Settings\n"
      "2. Booking Management\n"
      "3. Help Center\n\n"
      "Select an option or type your request"
    );

    List<QuickAction> actions = [
      QuickAction(
        icon: Icons.person_outline_rounded,
        text: '1',
        label: 'Profile',
        onTap: () => _handleMainMenuInput(1),
      ),
      QuickAction(
        icon: Icons.calendar_today_rounded,
        text: '2',
        label: 'Bookings',
        onTap: () => _handleMainMenuInput(2),
      ),
      QuickAction(
        icon: Icons.help_outline_rounded,
        text: '3',
        label: 'Help',
        onTap: () => _handleMainMenuInput(3),
      ),
    ];

    messages.last['quickActions'] = actions;
    setState(() {});
  }

  void _addBotMessage(String text) {
    setState(() {
      messages.add({
        'isBot': true,
        'message': text,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      messages.add({
        'isBot': false,
        'message': text,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
    _processUserMessage(text);
  }

  Future<void> _processUserMessage(String message) async {
    if (_awaitingNumericInput) {
      await _handleNumericInput(message);
      return;
    }

    final number = int.tryParse(message);
    if (number != null) {
      await _handleMainMenuInput(number);
      return;
    }

    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('profile') || lowerMessage.contains('update')) {
      _showProfileOptions();
    } else if (lowerMessage.contains('status') || lowerMessage.contains('booking')) {
      await _showBookingStatus();
    } else if (lowerMessage.contains('cancel')) {
      _showCancelBookingDialog();
    } else {
      _addBotMessage("I'm not sure how to help with that. Please choose from the options above or rephrase your request.");
    }
  }

  Future<void> _handleMainMenuInput(int number) async {
    switch (number) {
      case 1:
        _showProfileSubMenu();
        break;
      case 2:
        _showBookingSubMenu();
        break;
      case 3:
        _showHelpMenu();
        break;
      default:
        _addBotMessage("Please choose a number between 1 and 3.");
    }
  }

  void _showProfileSubMenu() {
    _addBotMessage(
      "Profile Options:\n\n"
      "1. Update Name\n"
      "2. Update Address\n"
      "3. Update Phone\n"
      "4. Back to Main Menu\n\n"
      "Type the number of your choice:"
    );
    _awaitingNumericInput = true;
    _currentAction = 'profile';
  }

  void _showBookingSubMenu() {
    _addBotMessage(
      "Booking Options:\n\n"
      "1. Check Booking Status\n"
      "2. Cancel Booking\n"
      "3. View Past Bookings\n"
      "4. Back to Main Menu\n\n"
      "Type the number of your choice:"
    );
    _awaitingNumericInput = true;
    _currentAction = 'booking';
  }

  void _showHelpMenu() {
    _addBotMessage(
      "How can I help you?\n\n"
      "1. Contact Support\n"
      "2. Privacy Policy\n"
      "3. Refund Policy\n"
      "4. Back to Main Menu\n\n"
      "Select an option:"
    );

    List<QuickAction> actions = [
      QuickAction(
        icon: Icons.support_agent_rounded,
        text: '1',
        label: 'Support',
        onTap: () => Navigator.pushNamed(context, '/help'),
      ),
      QuickAction(
        icon: Icons.privacy_tip_rounded,
        text: '2',
        label: 'Privacy',
        onTap: () => Navigator.pushNamed(context, '/privacy'),
      ),
      QuickAction(
        icon: Icons.receipt_long_rounded,
        text: '3',
        label: 'Refund',
        onTap: () => Navigator.pushNamed(context, '/refund'),
      ),
      QuickAction(
        icon: Icons.arrow_back_rounded,
        text: '4',
        label: 'Back',
        onTap: () => _showWelcomeMessage(),
      ),
    ];

    messages.last['quickActions'] = actions;
    setState(() {});
    _awaitingNumericInput = true;
    _currentAction = 'help';
  }

  Future<void> _handleHelpAction(int number) async {
    switch (number) {
      case 1:
        Navigator.pushNamed(context, '/help');
        break;
      case 2:
        Navigator.pushNamed(context, '/privacy');
        break;
      case 3:
        Navigator.pushNamed(context, '/refund');
        break;
      case 4:
        _showWelcomeMessage();
        break;
      default:
        _addBotMessage("Please choose a valid option.");
    }
  }

  Future<void> _handleNumericInput(String input) async {
    final number = int.tryParse(input);
    if (number == null) {
      _addBotMessage("Please enter a valid number.");
      return;
    }

    switch (_currentAction) {
      case 'profile':
        await _handleProfileAction(number);
        break;
      case 'cancel_booking':
        await _cancelBooking(number - 1);
        _awaitingNumericInput = false;
        _currentAction = '';
        break;
      case 'help':
        await _handleHelpAction(number);
        break;
    }

    _awaitingNumericInput = false;
    _currentAction = '';
  }

  Future<void> _handleProfileAction(int number) async {
    switch (number) {
      case 1:
        _showNameUpdateDialog();
        break;
      case 2:
        _showAddressUpdateDialog();
        break;
      case 3:
        _showPhoneUpdateDialog();
        break;
      case 4:
        _showWelcomeMessage();
        break;
      default:
        _addBotMessage("Please choose a valid option.");
    }
  }

  Future<void> _updateUserData(Map<String, dynamic> updates) async {
    try {
      if (_currentUid == null) return;

      await _database.child('users/$_currentUid').update(updates);
      await _loadUserData();
      _addBotMessage("Updated successfully! 👍");
    } catch (e) {
      _addBotMessage("Failed to update. Please try again.");
    }
  }

  void _showNameUpdateDialog() {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: _userData?['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.brightness == Brightness.dark 
            ? Colors.grey[900] 
            : Colors.white,
        title: Text('Update Name',
          style: TextStyle(color: Colors.deepOrange[700]),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: Colors.deepOrange[400]),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.deepOrange[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.deepOrange[400]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.deepOrange[200]!),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', 
              style: TextStyle(color: Colors.deepOrange[300]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange[400],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateUserData({'name': controller.text.trim()});
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddressUpdateDialog() {
    final doornumController = TextEditingController(text: _userData?['doornum']);
    final addressController = TextEditingController(text: _userData?['address']);
    final landmarkController = TextEditingController(text: _userData?['landmark']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Address'),
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
            const SizedBox(height: 8),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserData({
                'doornum': doornumController.text.trim(),
                'address': addressController.text.trim(),
                'landmark': landmarkController.text.trim(),
              });
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showPhoneUpdateDialog() {
    final controller = TextEditingController(text: _userData?['phone']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Phone'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUserData({'phone': controller.text.trim()});
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBookingStatus() async {
    try {
      if (_currentUid == null) {
        _addBotMessage("Please login to view your bookings.");
        return;
      }

      _addBotMessage("Fetching your active bookings...");
      
      final bookingsSnapshot = await _database
          .child('bookings')
          .orderByChild('userId')
          .equalTo(_currentUid)
          .get();

      if (!bookingsSnapshot.exists) {
        _addBotMessage("You don't have any active bookings.");
        return;
      }

      final bookings = <BookingModel>[];
      final bookingsData = Map<String, dynamic>.from(bookingsSnapshot.value as Map);
      
      bookingsData.forEach((key, value) {
        final data = Map<String, dynamic>.from(value);
        data['id'] = key;
        if (data['status'] != 'cancelled' && data['status'] != 'completed') {
          bookings.add(BookingModel.fromJson(data));
        }
      });

      if (bookings.isEmpty) {
        _addBotMessage("You don't have any active bookings at the moment.");
        return;
      }

      bookings.sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
      _displayBookings(bookings);

    } catch (e) {
      print('Error fetching bookings: $e');
      _addBotMessage("Sorry, I couldn't fetch your booking status. Please try again later.");
    }
  }

  void _displayBookings(List<BookingModel> bookings) {
    String message = "Your Active Bookings:\n\n";
    for (var booking in bookings) {
      message += "${booking.serviceName}\n"
          "━━━━━━━━━━━━━━━━━━━━━━\n"
          "📅 ${booking.formattedDate}\n"
          "${_getStatusText(booking.status)}\n"
          "💰 ₹${booking.amount?.toStringAsFixed(0) ?? '0'}\n"
          "━━━━━━━━━━━━━━━━━━━━━━\n\n";
    }
    _addBotMessage(message);
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '⌛ Waiting for confirmation';
      case 'confirmed':
        return '✅ Service confirmed';
      case 'on the way':
        return '🚶 Service provider on the way';
      case 'ongoing':
        return '🔧 Service in progress';
      case 'completed':
        return '✨ Service completed';
      case 'cancelled':
        return '❌ Service cancelled';
      default:
        return '📝 Status: $status';
    }
  }

  void _showProfileOptions() {
    _addBotMessage("What would you like to update?\n\n"
        "• Name\n"
        "• Address\n"
        "• Phone number\n\n"
        "Just type what you'd like to update!");
  }

  void _showCancelBookingDialog() async {
    try {
      if (_currentUid == null) {
        _addBotMessage("Please login to cancel bookings.");
        return;
      }

      final bookingsSnapshot = await _database
          .child('bookings')
          .orderByChild('userId')
          .equalTo(_currentUid)
          .get();

      if (!bookingsSnapshot.exists) {
        _addBotMessage("You don't have any bookings to cancel.");
        return;
      }

      final bookings = <BookingModel>[];
      final bookingsData = Map<String, dynamic>.from(bookingsSnapshot.value as Map);
      
      bookingsData.forEach((key, value) {
        final data = Map<String, dynamic>.from(value);
        data['id'] = key;
        if (data['status'] != 'cancelled' && data['status'] != 'completed') {
          bookings.add(BookingModel.fromJson(data));
        }
      });

      if (bookings.isEmpty) {
        _addBotMessage("You don't have any active bookings to cancel.");
        return;
      }

      String message = "Which booking would you like to cancel?\n\n";
      for (var (index, booking) in bookings.indexed) {
        message += "${index + 1}. ${booking.serviceName}\n"
            "   Date: ${booking.formattedDate}\n"
            "   Time: ${booking.timeSlot}\n"
            "   Status: ${booking.status}\n\n";
      }
      _addBotMessage(message);

      _currentAction = 'cancel_booking';
      _awaitingNumericInput = true;

    } catch (e) {
      print('Error fetching bookings for cancellation: $e');
      _addBotMessage("Sorry, I couldn't fetch your bookings. Please try again later.");
    }
  }

  Future<void> _cancelBooking(int index) async {
    try {
      final bookingsSnapshot = await _database
          .child('bookings')
          .orderByChild('userId')
          .equalTo(_currentUid)
          .get();

      if (!bookingsSnapshot.exists) {
        _addBotMessage("You don't have any bookings to cancel.");
        return;
      }

      final bookings = <BookingModel>[];
      final bookingsData = Map<String, dynamic>.from(bookingsSnapshot.value as Map);
      
      bookingsData.forEach((key, value) {
        final data = Map<String, dynamic>.from(value);
        data['id'] = key;
        if (data['status'] != 'cancelled' && data['status'] != 'completed') {
          bookings.add(BookingModel.fromJson(data));
        }
      });

      if (index < 0 || index >= bookings.length) {
        _addBotMessage("Invalid booking selection.");
        return;
      }

      final booking = bookings[index];
      
      await _database
          .child('bookings/${booking.id}')
          .update({
            'status': 'cancelled',
            'cancelledAt': DateTime.now().millisecondsSinceEpoch,
          });

      _addBotMessage(
        "Booking cancelled successfully!\n\n"
        "Service: ${booking.serviceName}\n"
        "Status: Cancelled\n"
        "Date: ${booking.formattedDate}\n"
        "Time: ${booking.timeSlot}\n"
        "Amount: ₹${booking.amount?.toStringAsFixed(0) ?? '0'}"
      );

      await _showBookingStatus();

    } catch (e) {
      print('Error cancelling booking: $e');
      _addBotMessage("Sorry, I couldn't cancel the booking. Please try again later.");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildQuickActionButtons(String message) {
    List<QuickAction> actions = [];
    final mainMenuAction = QuickAction(
      icon: Icons.home,
      label: 'Main Menu',
      onTap: () => _showWelcomeMessage(), 
      text: '',
    );

    if (message.contains("Profile Options")) {
      actions = [
        QuickAction(
          icon: Icons.person_outline,
          text: '1',
          label: 'Name',
          onTap: () => _handleProfileAction(1),
        ),
        QuickAction(
          icon: Icons.location_on_outlined,
          text: '2',
          label: 'Address',
          onTap: () => _handleProfileAction(2),
        ),
        QuickAction(
          icon: Icons.phone_outlined,
          text: '3',
          label: 'Phone',
          onTap: () => _handleProfileAction(3),
        ),
        QuickAction(
          icon: Icons.arrow_back,
          text: '4',
          label: 'Back',
          onTap: () => _showWelcomeMessage(),
        ),
      ];
    } else if (message.contains("Booking Options")) {
      actions = [
        QuickAction(
          icon: Icons.check_circle_outline,
          text: '1',
          label: 'Check Status',
          onTap: () => _showBookingStatus(),
        ),
        QuickAction(
          icon: Icons.cancel_outlined,
          text: '2',
          label: 'Cancel',
          onTap: () => _showCancelBookingDialog(),
        ),
        QuickAction(
          icon: Icons.history,
          text: '3',
          label: 'Past Bookings',
          onTap: () => _addBotMessage("Feature not implemented yet."),
        ),
        QuickAction(
          icon: Icons.arrow_back,
          text: '4',
          label: 'Back',
          onTap: () => _showWelcomeMessage(),
        ),
      ];
    } else if (message.contains("How can I help you")) {
      actions = [
        QuickAction(
          icon: Icons.support_agent,
          text: '1',
          label: 'Support',
          onTap: () => _handleHelpAction(1),
        ),
        QuickAction(
          icon: Icons.privacy_tip,
          text: '2',
          label: 'Privacy',
          onTap: () => _handleHelpAction(2),
        ),
        QuickAction(
          icon: Icons.receipt_long,
          text: '3',
          label: 'Refund',
          onTap: () => _handleHelpAction(3),
        ),
        QuickAction(
          icon: Icons.arrow_back,
          text: '4',
          label: 'Back',
          onTap: () => _showWelcomeMessage(),
        ),
      ];
    } else if (message.contains("Your Active Bookings")) {
      actions = [
        QuickAction(
          icon: Icons.refresh,
          text: '',
          label: 'Refresh',
          onTap: () => _showBookingStatus(),
        ),
        QuickAction(
          icon: Icons.cancel_outlined,
          text: '',
          label: 'Cancel Booking',
          onTap: () => _showCancelBookingDialog(),
        ),
        mainMenuAction,
      ];
    } else if (message.contains("How can I assist you today?")) {
      actions = List<QuickAction>.from(messages.last['quickActions'] ?? []);
    } else if (messages.isNotEmpty && 
        messages.last['message'] == message && 
        messages.last['cancelActions'] != null) {
      actions = List<QuickAction>.from(messages.last['cancelActions']);
      actions.add(mainMenuAction);
    }

    if (actions.isEmpty) {
      actions = [mainMenuAction];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) => _buildAnimatedActionButton(action)).toList(),
      ),
    );
  }

  Widget _buildAnimatedActionButton(QuickAction action) {
    return ElevatedButton(
      onPressed: action.onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
        foregroundColor: AppTheme.primaryColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            action.icon,
            size: 18,
          ),
          if (action.label != null) ...[
            const SizedBox(width: 8),
            Text(
              action.label!,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isBot = message['isBot'] as bool;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryColor.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.smart_toy,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
          Container(
            width: 300,
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isBot ? theme.cardColor : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                    gradient: isBot
                        ? null
                        : LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.8),
                            ],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isBot
                            ? theme.shadowColor.withOpacity(0.08)
                            : AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    message['message'] as String,
                    style: TextStyle(
                      color: isBot ? theme.textTheme.bodyLarge?.color : Colors.white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                if (isBot) 
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildQuickActionButtons(message['message'] as String),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class QuickAction {
  final IconData icon;
  final String text;
  final String? label;
  final VoidCallback onTap;

  QuickAction({
    required this.icon,
    required this.text,
    this.label,
    required this.onTap,
  });
}
