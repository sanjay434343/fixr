import 'package:flutter/material.dart';

class AppColors {
  // Add orange color constants
  static const orange = {
    50: Color(0xFFFFF3E0),
    100: Color(0xFFFFE0B2),
    200: Color(0xFFFFCC80),
    300: Color(0xFFFFB74D),
    400: Color(0xFFFFA726),
    500: Color(0xFFF57C00),
    600: Color(0xFFF57C00),
    700: Color(0xFFEF6C00),
    800: Color(0xFFE65100),
    900: Color(0xFFE65100),
  };

  // Helper method to get orange shade
  static Color getOrangeShade(int shade) {
    return orange[shade] ?? orange[500]!;
  }

  static Color cardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]!
        : Colors.white;
  }

  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[700]!
        : Colors.grey[200]!;
  }

  static Color textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  static Color secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[300]!
        : Colors.grey[600]!;
  }
}
