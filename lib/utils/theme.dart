import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Apple-style design tokens.
///
/// Dark mode follows iOS "grouped" dark: true black ground, elevated
/// #1C1C1E cells, hairline separators, and one system accent. Light mode
/// mirrors grouped light (#F2F2F7 ground, white cells).
class AppColors {
  AppColors._();

  // Accent — iOS system green. Cricket = grass; one accent, used sparingly.
  static const Color primary = Color(0xFF30D158);
  static const Color secondary = Color(0xFF0A84FF);

  // Grounds & cells
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color cellElevated = Color(0xFF2C2C2E);

  // Labels — iOS dark-mode label ramp
  static const Color textBody = Color(0xFFEBEBF5); // primary label
  static const Color textMuted = Color(0x99EBEBF5); // secondary label (60%)
  static const Color textFaint = Color(0x4DEBEBF5); // tertiary label (30%)

  // Misc
  static const Color error = Color(0xFFFF453A);
  static const Color separator = Color(0x2EFFFFFF); // hairline over black
}

class AppTheme {
  AppTheme._();

  // iOS type stack approximated with the system font (SF on iOS/Apple
  // platforms by default). Tracking is size-specific: negative on large
  // sizes, near-zero on body, and slightly positive on the smallest text.
  static const TextTheme _darkText = TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textBody,
      letterSpacing: -0.4,
      height: 1.1,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textBody,
      letterSpacing: -0.4,
      height: 1.1,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textBody,
      letterSpacing: -0.3,
      height: 1.2,
    ),
    titleLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppColors.textBody,
      height: 1.3,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textBody,
      height: 1.35,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textBody,
      height: 1.35,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 1.35,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      letterSpacing: 0.2,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    textTheme: _darkText,
    iconTheme: const IconThemeData(color: AppColors.textBody),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
    ),
    // iOS-style bottom sheets: elevated cell material, grab handle.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
      dragHandleColor: AppColors.textFaint,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textBody,
      textColor: AppColors.textBody,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.cellElevated,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: AppColors.textBody, fontSize: 14),
      padding: EdgeInsets.symmetric(horizontal: 8),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: Colors.white,
      inactiveTrackColor: AppColors.cellElevated,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.cellElevated,
      contentTextStyle: TextStyle(color: AppColors.textBody, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
    // Dark color redo keeps error as iOS red.
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(AppColors.textFaint),
    ),
  );

  /// Grouped-light mirror. Dark is the shipped default (themeMode: dark);
  /// this exists so a future theme toggle lands correctly.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF34C759),
      secondary: Color(0xFF007AFF),
      surface: Colors.white,
      error: Color(0xFFFF3B30),
    ),
    textTheme: _darkText.apply(
      bodyColor: const Color(0xFF1C1C1E),
      displayColor: const Color(0xFF1C1C1E),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF34C759),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
  );
}

/// Shared blurred-material chrome (player capsules, tab bar).
class Glass {
  Glass._();

  /// Translucent dark material: heavy blur + a hairline bright edge, so
  /// floating chrome reads as a real material over the content beneath.
  static Widget container({
    required Widget child,
    double radius = 10,
    double sigma = 30,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0x28FFFFFF)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// 40×40 circular glass button backing for player chrome.
  static Widget circle({required Widget child}) {
    return container(
      radius: 20,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }

  // AppTitle style used by sheets and list headers.
  static const TextStyle titleStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textBody,
  );
}
