import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_radius.dart';

/// The Muse theme ("Golden Hour").
///
/// One app bar for every screen (the page colour, ink text, no fill), ink text on coral buttons,
/// flat white cards on cream, and Plus Jakarta Sans throughout. A screen should get its look from
/// here; a colour, radius or text style typed into a widget is a bug to fix, not a pattern to copy.
class AppTheme {
  AppTheme._();

  /// Bundled in `assets/fonts/` (SIL Open Font License) and declared in `pubspec.yaml`.
  static const String fontFamily = 'PlusJakartaSans';

  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.primaryTint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.primaryDeep,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.primaryTint,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.textSecondary,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.disabled,
    onTertiaryContainer: AppColors.ink,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: Color(0xFFFBE3DF),
    onErrorContainer: Color(0xFF5C1610),
    surface: AppColors.white,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceDim: AppColors.disabled,
    surfaceBright: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: Color(0xFFFFFAF7),
    surfaceContainer: AppColors.background,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: Color(0xFFF6E4DA),
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    shadow: AppColors.ink,
    scrim: AppColors.ink,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.primaryOrangeLight,
    surfaceTint: Colors.transparent,
  );

  static TextStyle _text(
    double size,
    FontWeight weight, {
    Color color = AppColors.textPrimary,
    double height = 1.4,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static final TextTheme _textTheme = TextTheme(
    displayLarge: _text(32, FontWeight.w800, height: 1.15, letterSpacing: -0.6),
    displayMedium: _text(28, FontWeight.w800, height: 1.15, letterSpacing: -0.5),
    displaySmall: _text(24, FontWeight.w800, height: 1.2, letterSpacing: -0.4),
    headlineLarge: _text(22, FontWeight.w700, height: 1.25, letterSpacing: -0.3),
    headlineMedium: _text(20, FontWeight.w700, height: 1.25, letterSpacing: -0.2),
    headlineSmall: _text(18, FontWeight.w700, height: 1.3, letterSpacing: -0.2),
    titleLarge: _text(18, FontWeight.w600),
    titleMedium: _text(16, FontWeight.w600),
    titleSmall: _text(14, FontWeight.w600),
    bodyLarge: _text(16, FontWeight.w400, height: 1.5),
    bodyMedium: _text(14, FontWeight.w400, height: 1.5),
    bodySmall: _text(12, FontWeight.w400, color: AppColors.textSecondary, height: 1.5),
    labelLarge: _text(14, FontWeight.w600),
    labelMedium: _text(12, FontWeight.w600, color: AppColors.textSecondary),
    labelSmall: _text(11, FontWeight.w600, color: AppColors.textTertiary),
  );

  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// A text button for the way out of something ("Not now", "Go back", "Cancel this date"):
  /// muted, so it never competes with the screen's action. Pass it as a [TextButton]'s style.
  static final ButtonStyle quietLink = TextButton.styleFrom(
    foregroundColor: AppColors.textSecondary,
  );

  static final RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),

      // One app bar: the page colour, ink text, no fill and no shadow.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: _text(18, FontWeight.w700, letterSpacing: -0.2),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // Text fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(AppColors.border, 1),
        enabledBorder: _inputBorder(AppColors.border, 1),
        focusedBorder: _inputBorder(AppColors.primaryDeep, 2),
        errorBorder: _inputBorder(AppColors.error, 1),
        focusedErrorBorder: _inputBorder(AppColors.error, 2),
        disabledBorder: _inputBorder(AppColors.disabled, 1),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: AppColors.primaryDeep),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primaryDeep,
        selectionColor: AppColors.primary.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.primaryDeep,
      ),

      // Primary button: coral with ink text.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.disabledText,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: _buttonShape,
          textStyle: _text(16, FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: AppColors.disabledText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: _buttonShape,
          textStyle: _text(16, FontWeight.w700),
        ),
      ),

      // Secondary button: an ink outline.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.disabledText,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: _buttonShape,
          textStyle: _text(16, FontWeight.w700),
        ).copyWith(
          // The outline fades with the label when the button is off.
          side: WidgetStateProperty.resolveWith((states) {
            final off = states.contains(WidgetState.disabled);
            return BorderSide(
              color: off ? AppColors.border : AppColors.textPrimary,
              width: 1.2,
            );
          }),
        ),
      ),

      // Text button and links: deep coral, readable on cream and white.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDeep,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: _buttonShape,
          textStyle: _text(14, FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 1,
        highlightElevation: 1,
        shape: _buttonShape,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Flat white card. The hairline keeps it visible on a white page too.
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: const EdgeInsets.all(8),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: _text(20, FontWeight.w700, height: 1.25, letterSpacing: -0.2),
        contentTextStyle: _text(14, FontWeight.w400, height: 1.5),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        modalBackgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppColors.border,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),

      // Chips: a tint pill; coral when selected.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryTint,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.disabled,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: AppColors.textOnPrimary,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: _text(14, FontWeight.w500),
        secondaryLabelStyle: _text(14, FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        actionTextColor: AppColors.primaryOrangeLight,
        contentTextStyle: _text(14, FontWeight.w500, color: AppColors.white),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.divider,
        circularTrackColor: Colors.transparent,
      ),

      // Tab bar at the bottom of the app: a tint pill behind the selected icon.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primaryTint,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.primaryDeep : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _text(
            12,
            selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primaryDeep : AppColors.textSecondary,
            height: 1.2,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryDeep,
        unselectedItemColor: AppColors.textSecondary,
        selectedLabelStyle: _text(12, FontWeight.w700, height: 1.2),
        unselectedLabelStyle: _text(12, FontWeight.w500, height: 1.2),
        elevation: 0,
      ),

      // Tabs inside a screen
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primaryDeep,
        dividerColor: AppColors.divider,
        labelStyle: _text(14, FontWeight.w700),
        unselectedLabelStyle: _text(14, FontWeight.w500),
      ),

      // Toggles
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabledText;
          return AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabled;
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.textOnPrimary),
        side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.disabledText;
          if (states.contains(WidgetState.selected)) return AppColors.primaryDeep;
          return AppColors.textTertiary;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: AppColors.ink,
        valueIndicatorTextStyle: _text(12, FontWeight.w600, color: AppColors.white),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: _text(14, FontWeight.w500),
      ),
    );
  }
}
