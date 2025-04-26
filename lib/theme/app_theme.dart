import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFFF57C00); // Changed to orange
  static const secondaryColor = Color(0xFF263238);
  static const accentColor = Color(0xFF455A64);
  
  static final MaterialColor primarySwatch = MaterialColor(
    primaryColor.value,
    const <int, Color>{
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
    },
  );

  static final lightTheme = ThemeData(
    primaryColor: primaryColor,
    primarySwatch: primarySwatch,
    fontFamily: 'Inter',
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor.withOpacity(0.95),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primaryColor.withOpacity(0.1),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) 
              ? primaryColor 
              : Colors.grey[600],
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) 
              ? primaryColor 
              : Colors.grey[600],
          size: 24,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: Colors.grey[800],
    dividerColor: Colors.grey[700],
    colorScheme: const ColorScheme.dark().copyWith(
      primary: primaryColor,
      secondary: primaryColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[900],
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.grey[900],
      indicatorColor: primaryColor.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) 
              ? primaryColor 
              : Colors.grey[400],
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) 
              ? primaryColor 
              : Colors.grey[400],
          size: 24,
        );
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
