import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HealthMate visual language: white + mint surfaces, teal accents, deep navy
/// text. Restrained shadows, generous spacing and consistent radii keep the
/// product calm and clinical rather than decorative.
class AppColors {
  AppColors._();

  static const teal = Color(0xFF0F9D8A);
  static const tealDark = Color(0xFF0A7467);
  static const tealSoft = Color(0xFFE6F7F2);
  static const mintBackground = Color(0xFFF4FBF8);
  static const navy = Color(0xFF0B1F33);
  static const slate = Color(0xFF526579);
  static const muted = Color(0xFF718096);
  static const border = Color(0xFFE1ECE7);
  static const surface = Colors.white;
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFEF3F2);
  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFFAEB);
  static const success = Color(0xFF067647);
  static const successSoft = Color(0xFFECFDF3);
}

class AppRadii {
  AppRadii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 26.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final baseText = GoogleFonts.interTextTheme();
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      secondary: AppColors.tealDark,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.mintBackground,
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: AppColors.navy,
          height: 1.55,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: AppColors.slate,
          height: 1.5,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: AppColors.muted,
          height: 1.45,
        ),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mintBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.navy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
        labelStyle: const TextStyle(color: AppColors.slate, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.slate,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBFE3DA),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tealDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.teal,
        disabledColor: const Color(0xFFF0F5F3),
        labelStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.tealSoft,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.tealDark
                : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.teal,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.slate,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

/// A readable content column for desktop/tablet. Keeps the browser experience
/// app-like instead of stretching cards across the whole monitor.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
