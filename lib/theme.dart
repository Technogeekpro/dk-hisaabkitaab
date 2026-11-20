import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'settings.dart';

/// Neutral, minimal palette. One ink colour for actions, green for money
/// you keep, red for money going out.
abstract final class AppColors {
  static const background = Color(0xFFF6F6F7);
  static const surface = Colors.white;
  static const border = Color(0xFFE7E7EA);
  static const divider = Color(0xFFF0F0F2);
  static const fill = Color(0xFFF2F2F4);
  static const text = Color(0xFF111113);
  static const textMuted = Color(0xFF6B6B74);
  static const textFaint = Color(0xFFA1A1A9);
  static const positive = Color(0xFF15803D);
  static const positiveSoft = Color(0xFFEAF6EE);
  static const negative = Color(0xFFD92D20);
  static const negativeSoft = Color(0xFFFDEEEC);
}

const tabularFigures = [FontFeature.tabularFigures()];

abstract final class AppText {
  static const pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.15,
    color: AppColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.text,
  );
  static const sheetTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.text,
  );
  static const display = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
    height: 1.1,
    color: AppColors.text,
    fontFeatures: tabularFigures,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
  static const caption = TextStyle(fontSize: 12, color: AppColors.textMuted);
  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.text,
  );
  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: AppColors.text,
  );
  static const amount = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.text,
    fontFeatures: tabularFigures,
  );
  static const metric = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: AppColors.text,
    fontFeatures: tabularFigures,
  );
}

final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _moneyWhole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String money(num value) =>
    (appSettings.showPaise ? _money : _moneyWhole).format(value);

const systemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
);

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.text,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: AppColors.text,
        onPrimary: Colors.white,
        secondary: AppColors.text,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textMuted,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Colors.white,
        surfaceContainerHighest: AppColors.fill,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        error: AppColors.negative,
      );
  final radius12 = BorderRadius.circular(12);
  const buttonText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
          fontFamily: 'Inter',
        )
        .copyWith(
          headlineMedium: AppText.pageTitle,
          titleLarge: AppText.sheetTitle,
          titleMedium: AppText.sectionTitle,
          bodyLarge: AppText.body,
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.45,
            letterSpacing: -0.05,
            color: AppColors.text,
          ),
          bodySmall: AppText.caption,
          labelLarge: buttonText,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemUiStyle,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(
        color: AppColors.text,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: AppColors.textFaint),
      helperStyle: AppText.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: const BorderSide(color: AppColors.text, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: const BorderSide(color: AppColors.negative),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: const BorderSide(color: AppColors.negative, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.text,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.fill,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: radius12),
        textStyle: buttonText.copyWith(fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        textStyle: buttonText.copyWith(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMuted,
        selectedBackgroundColor: AppColors.text,
        selectedForegroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(48, 48),
        textStyle: buttonText.copyWith(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.text),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.text,
      foregroundColor: Colors.white,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 1,
      shape: CircleBorder(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: AppText.sheetTitle.copyWith(fontSize: 19),
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        height: 1.45,
        color: AppColors.textMuted,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Colors.white,
      headerForegroundColor: AppColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.text,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
      titleTextStyle: AppText.rowTitle,
      subtitleTextStyle: AppText.caption,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.text
            : AppColors.border,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    radioTheme: const RadioThemeData(
      fillColor: WidgetStatePropertyAll(AppColors.text),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.text,
      refreshBackgroundColor: Colors.white,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        color: Colors.white,
        fontSize: 12,
      ),
    ),
  );
}
