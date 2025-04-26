import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'email_verification_screen.dart';  // Add this import

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _doorNumberController = TextEditingController();
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  late AnimationController _animController;
  int _currentStep = 1;
  String? _fcmToken;
  DateTime? _lastVerificationAttempt;
  static const _verificationCooldown = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animController.forward();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    try {
      final fcm = FirebaseMessaging.instance;
      final settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _fcmToken = await fcm.getToken();
        print('FCM Token: $_fcmToken');
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _doorNumberController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleNextStep() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentStep == 1) {
      setState(() => _isLoading = true);
      try {
        // Create user without verification
        final userCredential = await _authService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          {},  // Empty data initially
        );

        if (mounted) {
          setState(() => _currentStep = 2);
        }
      } catch (e) {
        String errorMessage = 'An error occurred during signup.';
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = 'This email is already registered.';
              break;
            case 'invalid-email':
              errorMessage = 'Please enter a valid email address.';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Email/password accounts are not enabled.';
              break;
            case 'weak-password':
              errorMessage = 'Please enter a stronger password.';
              break;
            default:
              errorMessage = e.message ?? errorMessage;
          }
        }
        setState(() => _errorMessage = errorMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    } else if (_currentStep == 2) {
      await _completeSignup();
    }
  }

  Future<void> _completeSignup() async {
    try {
      setState(() => _isLoading = true);
      
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user found');

      // Create user data object
      final userData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'doornum': _doorNumberController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'fcmToken': _fcmToken,
        'createdAt': DateTime.now().toIso8601String(),
        'isVerified': false
      };

      // Store in Realtime Database
      await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(user.uid)
          .set(userData);

      // Send verification email
      await user.sendEmailVerification();

      if (mounted) {
        // Navigate to verification screen directly
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
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
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: size.height,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primaryColor.withOpacity(0.1),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios, color: theme.primaryColor),
                            onPressed: () {
                              if (_currentStep == 2) {
                                setState(() => _currentStep = 1);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                          ),
                          const Spacer(),
                          Text(
                            'Step $_currentStep of 2',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Hero(
                        tag: 'logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 100,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.home_repair_service,
                            size: 100,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _currentStep == 1 ? 'Create Account' : 'Personal Details',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentStep == 1 
                          ? 'Enter your account details'
                          : 'Enter your contact information',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentStep == 1
                            ? _buildStep1Fields()
                            : _buildStep2Fields(),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red.shade700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleNextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: theme.scaffoldBackgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          shadowColor: theme.primaryColor.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _currentStep == 1 ? 'NEXT' : 'CREATE ACCOUNT',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                      ),
                      if (_currentStep == 1)
                        Padding(
                          padding: EdgeInsets.only(
                            top: 16,
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Already have an account?"),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Fields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAnimatedField(
          controller: _nameController,
          icon: Icons.person_outline,
          label: 'Full Name',
          delay: 0.1,
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _buildAnimatedField(
          controller: _emailController,
          icon: Icons.email_outlined,
          label: 'Email',
          delay: 0.2,
          keyboardType: TextInputType.emailAddress,
          validator: (value) => !value!.contains('@') ? 'Invalid email' : null,
        ),
        const SizedBox(height: 16),
        _buildAnimatedField(
          controller: _passwordController,
          icon: Icons.lock_outline,
          label: 'Password',
          isPassword: true,
          delay: 0.3,
          validator: (value) => value!.length < 6 ? '6+ characters required' : null,
        ),
        const SizedBox(height: 16),
        _buildAnimatedField(
          controller: _confirmPasswordController,
          icon: Icons.lock_outline,
          label: 'Confirm Password',
          isPassword: true,
          delay: 0.4,
          validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
        ),
      ],
    );
  }

  Widget _buildStep2Fields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAnimatedField(
          controller: _phoneController,
          icon: Icons.phone_outlined,
          label: 'Phone',
          hint: 'Enter 10-digit mobile number',
          delay: 0.1,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            // Validate 10-digit Indian mobile number
            if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
              return 'Enter valid 10-digit mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildAnimatedField(
          controller: _addressController,
          icon: Icons.location_on_outlined,
          label: 'Address',
          delay: 0.2,
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnimatedField(
                controller: _doorNumberController,
                icon: Icons.home_outlined,
                label: 'Door No.',
                delay: 0.3,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedField(
                controller: _landmarkController,
                icon: Icons.place_outlined,
                label: 'Landmark',
                delay: 0.3,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    required double delay,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Interval(delay, delay + 0.2, curve: Curves.easeOut),
      )),
      child: Card(
        color: theme.cardColor,
        elevation: 8,
        shadowColor: theme.primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword && _obscurePassword,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: TextStyle(color: theme.primaryColor),
            prefixIcon: Icon(icon, color: theme.primaryColor, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: theme.primaryColor,
                      size: 22,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: theme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: theme.cardColor,
            focusColor: theme.primaryColor,
          ),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          cursorColor: theme.primaryColor,
          validator: validator,
        ),
      ),
    );
  }
}
