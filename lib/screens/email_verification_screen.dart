import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> with SingleTickerProviderStateMixin {
  final auth = FirebaseAuth.instance;
  Timer? _timer;
  bool _isEmailVerified = false;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  DateTime? _lastVerificationAttempt;
  static const _verificationCooldown = Duration(minutes: 5);

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    String name = parts[0];
    String domain = parts[1];
    
    if (name.length <= 3) {
      return email;
    }
    
    return '${name.substring(0, 3)}${'*' * (name.length - 3)}@$domain';
  }

  @override
  void initState() {
    super.initState();
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    // Check if we have an unverified user
    final user = auth.currentUser;
    if (user == null) {
      // No user found, redirect to login
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    // Start verification process
    if (!user.emailVerified) {
      _startVerificationCheck();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      if (_lastVerificationAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(_lastVerificationAttempt!);
        if (timeSinceLastAttempt < _verificationCooldown) {
          final remainingSeconds = (_verificationCooldown - timeSinceLastAttempt).inSeconds;
          throw 'Please wait $remainingSeconds seconds before requesting another email.';
        }
      }

      await auth.currentUser?.sendEmailVerification();
      setState(() => _lastVerificationAttempt = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        setState(() => _lastVerificationAttempt = DateTime.now());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.code == 'too-many-requests' 
            ? 'Too many attempts. Please wait 5 minutes.'
            : 'Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        try {
          await auth.currentUser?.reload();
          final user = auth.currentUser;
          if (user?.emailVerified ?? false) {
            _timer?.cancel();
            setState(() => _isEmailVerified = true);
            
            // Update verification status in database
            await FirebaseDatabase.instance
                .ref()
                .child('users')
                .child(user!.uid)
                .update({'isVerified': true});

            // Show success message and redirect
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email verified! Please log in.'),
                backgroundColor: Colors.green,
              ),
            );

            // Sign out and redirect to login
            await auth.signOut();
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed('/login');
          }
        } catch (e) {
          debugPrint('Error checking email verification: $e');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Email Verification',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: theme.primaryColor,
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            CustomPaint(
              painter: BackgroundPatternPainter(
                color: theme.primaryColor.withOpacity(0.1)
              ),
              size: Size.infinite,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon and animations
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!_isEmailVerified)
                                    AnimatedBuilder(
                                      animation: _progressAnimation,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: LoadingCirclePainter(
                                            progress: _progressAnimation.value,
                                            color: theme.primaryColor,
                                          ),
                                          size: const Size(120, 120),
                                        );
                                      },
                                    ),
                                  Icon(
                                    _isEmailVerified ? Icons.verified : Icons.mark_email_unread,
                                    size: 80,
                                    color: _isEmailVerified ? Colors.green[700] : theme.primaryColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
                              // Title with animation
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutBack,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  _isEmailVerified ? 'Email Verified!' : 'Verify Your Email',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: _isEmailVerified ? Colors.green[700] : theme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Masked email display
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                                ),
                                child: Text(
                                  _maskEmail(auth.currentUser?.email),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: theme.primaryColorDark,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              if (!_isEmailVerified) ...[
                                const SizedBox(height: 32),
                                const Text(
                                  'Please check your inbox and verify your email address.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom buttons container
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isEmailVerified)
                            ElevatedButton.icon(
                              onPressed: _sendVerificationEmail,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 54),
                                elevation: 8,
                                shadowColor: theme.primaryColor.withOpacity(0.4),
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text(
                                'Resend Verification Email',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () async {
                              await auth.signOut();
                              if (mounted) {
                                Navigator.of(context).pushReplacementNamed('/login');
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.primaryColor,
                              side: BorderSide(color: theme.primaryColor),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            child: const Text(
                              'Back to Login',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingCirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  LoadingCirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width / 2,
      ),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(LoadingCirclePainter oldDelegate) => progress != oldDelegate.progress;
}

class BackgroundPatternPainter extends CustomPainter {
  final Color color;

  BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    const spacing = 30.0;
    const dotSize = 3.0;

    for (var i = 0.0; i < size.width; i += spacing) {
      for (var j = 0.0; j < size.height; j += spacing) {
        canvas.drawCircle(Offset(i, j), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(BackgroundPatternPainter oldDelegate) => color != oldDelegate.color;
}
