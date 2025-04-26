import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class EasterEggScreen extends StatefulWidget {
  const EasterEggScreen({super.key});

  @override
  State<EasterEggScreen> createState() => _EasterEggScreenState();
}

class _EasterEggScreenState extends State<EasterEggScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  int _pressCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLogoPress() async {
    setState(() {
      _isPressed = true;
      _pressCount++;
    });

    // Vibrate with different patterns based on press count
    switch (_pressCount) {
      case 1:
        HapticFeedback.heavyImpact();
        break;
      case 2:
        HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.vibrate();
        break;
      default:
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        HapticFeedback.mediumImpact();
    }

    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _controller.reverse();

    setState(() {
      _isPressed = false;
    });

    if (_pressCount >= 5) {
      setState(() => _pressCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: GestureDetector(
          onTapDown: (_) => _handleLogoPress(),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPressed 
                    ? AppTheme.primaryColor.withOpacity(0.3)
                    : Colors.transparent,
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
