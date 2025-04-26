import 'package:fixr/screens/email_verification_screen.dart';
import 'package:fixr/screens/help_screen.dart';
import 'package:fixr/screens/privacy_policy_screen.dart';
import 'package:fixr/screens/refund_screen.dart';
import 'package:fixr/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/service_providers_screen.dart';
import 'screens/provider_profile_screen.dart';
import 'screens/services_screen.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/version_service.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_logo.dart';
import 'services/theme_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notification service
  await NotificationService.initialize();

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      print('Foreground notification received: ${message.notification!.title}');
      // Display notification using a local notification package if needed
    }
  });

  // Configure Firebase Database
  final database = FirebaseDatabase.instance;
  database.setPersistenceEnabled(true);
  
  // Set log level for debug mode
  if (kDebugMode) {
    database.setLoggingEnabled(true);
  }

  // Keep only public references synced initially
  database.ref().child('appversion').keepSynced(true);
  database.ref().child('services').keepSynced(true);
  database.ref().child('servicePersons').keepSynced(true);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeService(prefs),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Fixr',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/splash', // Change initial route to splash
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/': (context) => const LoginScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignupScreen(),
            '/home': (context) => HomeScreen(uid: ''),
            '/verify-email': (context) => const EmailVerificationScreen(),
            '/services': (context) => const ServicesScreen(), // Add this route
            '/help': (context) => const HelpScreen(),
            '/privacy': (context) => const PrivacyPolicyScreen(),
            '/refund': (context) => const RefundScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/home') {
              final args = settings.arguments as Map<String, dynamic>;
              final uid = args['uid'] as String;

              return MaterialPageRoute(
                builder: (context) => HomeScreen(uid: uid),
              );
            }
            switch (settings.name) {
              case '/service-providers':
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => ServiceProvidersScreen(
                    category: args?['category'] as String?,
                    searchQuery: args?['searchQuery'] as String?,
                  ),
                );
              case '/provider-profile':
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => ProviderProfileScreen(
                    providerName: args?['providerName'] as String?,
                  ),
                );
              default:
                return null;
            }
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation and vibrate
    _animationController.forward().then((_) {
      HapticFeedback.mediumImpact();
      _checkVersionAndProceed();
    });
  }

  Future<void> _checkVersionAndProceed() async {
    try {
      final versionService = VersionService(FirebaseRemoteConfig.instance);
      final updateInfo = await versionService.checkForUpdate();

      if (updateInfo.needsUpdate && mounted) {
        await _showUpdateDialog(updateInfo);
      }

      // Only proceed if update is not required or user chose "Later"
      if (!updateInfo.forceUpdate) {
        await Future.delayed(const Duration(seconds: 2)); // Add delay for splash screen
        _checkLoginStatus();
      }
    } catch (e) {
      print('Version check error: $e');
      // Add delay even on error
      await Future.delayed(const Duration(seconds: 2));
      _checkLoginStatus();
    }
  }

  Future<void> _showUpdateDialog(UpdateInfo updateInfo) async {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !updateInfo.forceUpdate,
        child: AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update,
                  color: theme.primaryColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                updateInfo.updateMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current:',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      updateInfo.currentVersion,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Latest:',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                    Text(
                      updateInfo.latestVersion,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!updateInfo.forceUpdate) ...[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Later',
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                ),
              ),
            ],
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse(updateInfo.updateUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
                if (updateInfo.forceUpdate) {
                  await SystemNavigator.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (updateInfo.forceUpdate)
              TextButton.icon(
                onPressed: () => SystemNavigator.pop(),
                icon: Icon(Icons.exit_to_app, color: Colors.red[400], size: 20),
                label: Text(
                  'Exit App',
                  style: TextStyle(color: Colors.red[400]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/home',
            arguments: {'uid': user.uid}, // Pass the UID as a map
          );
        }
        return;
      }

      // If no user session, try auto login
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (mounted) {
        if (isLoggedIn && rememberMe) {
          try {
            final success = await _authService.autoLogin();
            if (success && _authService.currentUser != null) {
              Navigator.of(context).pushReplacementNamed('/home',
                arguments: {'uid': _authService.currentUser!.uid}
              );
              return;
            }
          } catch (e) {
            // If auto login fails, clear auth state
            await _authService.clearAuthState();
          }
        }
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Centered Logo
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedLogo(scaleAnimation: _scaleAnimation),
            ),
          ),
          
          // Bottom Content
          Positioned(
            left: 0,
            right: 0,
            bottom: 50, // Adjust this value to control bottom spacing
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  const SizedBox(height: 32),
                  Text(
                    'Fixr',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Home Service Partner',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
