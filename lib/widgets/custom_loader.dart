import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomLoader extends StatelessWidget {
  const CustomLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        strokeWidth: 2.5,
      ),
    );
  }
}
