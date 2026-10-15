import 'package:flutter/material.dart';

/// Raw brand color tokens (light + dark). Nothing outside this file should
/// reference these constants directly — go through [AppTheme.lightTheme] /
/// [AppTheme.darkTheme] ([ColorScheme], plus [AppColors] for the roles
/// [ColorScheme] has no slot for) so every color stays swappable from one
/// place.
class AppPalette {
  AppPalette._();

  static const primaryLight = Color(0xFF27374D);
  static const primaryDark = Color(0xFF5A7A9E);
  static const accentLight = Color(0xFF4A6B8A);
  static const accentDark = Color(0xFF8FB4D9);
  static const backgroundLight = Color(0xFFF7F9FC);
  static const backgroundDark = Color(0xFF121826);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1B2333);
  static const borderLight = Color(0xFFE1E7EF);
  static const borderDark = Color(0xFF2A3447);
  static const textPrimaryLight = Color(0xFF1A2433);
  static const textPrimaryDark = Color(0xFFEDF1F7);
  static const textSecondaryLight = Color(0xFF64748B);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const successLight = Color(0xFF16A34A);
  static const successDark = Color(0xFF4ADE80);
  static const errorLight = Color(0xFFDC2626);
  static const errorDark = Color(0xFFF87171);

  // Not part of the brand palette: the one amber needed for "Fair"
  // passwords and Blocked task badges.
  static const warningLight = Color(0xFFB45309);
  static const warningDark = Color(0xFFFBBF24);
}

/// Design-system colors with no home on [ColorScheme]: the AppBar/nav
/// chrome, dialog/dropdown surfaces, text field styling, the progress bar,
/// success/warning, and per-status task badges (To Do / In Progress /
/// Blocked / Completed / Overdue).
///
/// Access via `Theme.of(context).appColors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.sidebar,
    required this.sidebarBorder,
    required this.sidebarHover,
    required this.sidebarInactive,
    required this.sidebarSelected,
    required this.sidebarIndicator,
    required this.primaryHover,
    required this.textOnPage,
    required this.secondaryTextOnPage,
    required this.overlayBackground,
    required this.dialogBorder,
    required this.textFieldFill,
    required this.textFieldBorder,
    required this.progressTrack,
    required this.progressFill,
    required this.chipBackground,
    required this.chipText,
    required this.success,
    required this.warning,
    required this.logoTile,
    required this.avatarColors,
    required this.statusToDoBackground,
    required this.statusToDoText,
    required this.statusInProgressBackground,
    required this.statusInProgressText,
    required this.statusBlockedBackground,
    required this.statusBlockedText,
    required this.statusCompletedBackground,
    required this.statusCompletedText,
    required this.statusOverdueBackground,
    required this.statusOverdueText,
  });

  final Color sidebar;
  final Color sidebarBorder;
  final Color sidebarHover;
  final Color sidebarInactive;
  final Color sidebarSelected;
  final Color sidebarIndicator;
  final Color primaryHover;
  final Color textOnPage;
  final Color secondaryTextOnPage;
  final Color overlayBackground;
  final Color dialogBorder;
  final Color textFieldFill;
  final Color textFieldBorder;
  final Color progressTrack;
  final Color progressFill;
  final Color chipBackground;
  final Color chipText;

  /// "Available", met password rules, Good/Strong passwords.
  final Color success;

  /// "Fair" passwords.
  final Color warning;

  /// Behind the (transparent) logo mark — dark in both modes, since the
  /// mark is designed for a dark ground.
  final Color logoTile;

  /// Backgrounds for initials avatars (white text on each passes 4.5:1),
  /// picked deterministically per user.
  final List<Color> avatarColors;

  final Color statusToDoBackground;
  final Color statusToDoText;
  final Color statusInProgressBackground;
  final Color statusInProgressText;
  final Color statusBlockedBackground;
  final Color statusBlockedText;
  final Color statusCompletedBackground;
  final Color statusCompletedText;
  final Color statusOverdueBackground;
  final Color statusOverdueText;

  static const _avatarColors = [
    AppPalette.primaryLight,
    AppPalette.accentLight,
    AppPalette.textSecondaryLight,
    Color(0xFF334155),
    Color(0xFF3B5874),
  ];

  static final light = AppColors(
    // Chrome: the brand navy, as before.
    sidebar: AppPalette.primaryLight,
    sidebarBorder: AppPalette.textPrimaryDark.withValues(alpha: 0.12),
    sidebarHover: Colors.white.withValues(alpha: 0.08),
    sidebarInactive: AppPalette.textSecondaryDark,
    sidebarSelected: AppPalette.textPrimaryDark,
    sidebarIndicator: AppPalette.accentLight,
    primaryHover: AppPalette.textPrimaryLight,
    textOnPage: AppPalette.textPrimaryLight,
    secondaryTextOnPage: AppPalette.textSecondaryLight,
    overlayBackground: AppPalette.surfaceLight,
    dialogBorder: AppPalette.borderLight,
    textFieldFill: AppPalette.surfaceLight,
    textFieldBorder: AppPalette.borderLight,
    progressTrack: AppPalette.borderLight,
    progressFill: AppPalette.accentLight,
    chipBackground: AppPalette.accentLight.withValues(alpha: 0.12),
    chipText: AppPalette.primaryLight,
    success: AppPalette.successLight,
    warning: AppPalette.warningLight,
    logoTile: AppPalette.backgroundDark,
    avatarColors: _avatarColors,
    statusToDoBackground: AppPalette.borderLight,
    statusToDoText: AppPalette.textSecondaryLight,
    statusInProgressBackground: AppPalette.accentLight.withValues(alpha: 0.14),
    statusInProgressText: AppPalette.accentLight,
    statusBlockedBackground: AppPalette.warningLight.withValues(alpha: 0.12),
    statusBlockedText: AppPalette.warningLight,
    statusCompletedBackground: AppPalette.successLight.withValues(alpha: 0.12),
    statusCompletedText: AppPalette.successLight,
    statusOverdueBackground: AppPalette.errorLight.withValues(alpha: 0.10),
    statusOverdueText: AppPalette.errorLight,
  );

  static final dark = AppColors(
    // Chrome blends with the dark page instead of a lighter slab.
    sidebar: AppPalette.surfaceDark,
    sidebarBorder: AppPalette.borderDark,
    sidebarHover: Colors.white.withValues(alpha: 0.06),
    sidebarInactive: AppPalette.textSecondaryDark,
    sidebarSelected: AppPalette.textPrimaryDark,
    sidebarIndicator: AppPalette.primaryDark,
    primaryHover: Color.lerp(AppPalette.primaryDark, Colors.white, 0.12)!,
    textOnPage: AppPalette.textPrimaryDark,
    secondaryTextOnPage: AppPalette.textSecondaryDark,
    overlayBackground: AppPalette.surfaceDark,
    dialogBorder: AppPalette.borderDark,
    textFieldFill: AppPalette.surfaceDark,
    textFieldBorder: AppPalette.borderDark,
    progressTrack: AppPalette.borderDark,
    progressFill: AppPalette.accentDark,
    chipBackground: AppPalette.accentDark.withValues(alpha: 0.16),
    chipText: AppPalette.accentDark,
    success: AppPalette.successDark,
    warning: AppPalette.warningDark,
    logoTile: AppPalette.backgroundDark,
    avatarColors: _avatarColors,
    statusToDoBackground: AppPalette.borderDark,
    statusToDoText: AppPalette.textSecondaryDark,
    statusInProgressBackground: AppPalette.accentDark.withValues(alpha: 0.16),
    statusInProgressText: AppPalette.accentDark,
    statusBlockedBackground: AppPalette.warningDark.withValues(alpha: 0.14),
    statusBlockedText: AppPalette.warningDark,
    statusCompletedBackground: AppPalette.successDark.withValues(alpha: 0.14),
    statusCompletedText: AppPalette.successDark,
    statusOverdueBackground: AppPalette.errorDark.withValues(alpha: 0.14),
    statusOverdueText: AppPalette.errorDark,
  );

  @override
  AppColors copyWith({
    Color? sidebar,
    Color? sidebarBorder,
    Color? sidebarHover,
    Color? sidebarInactive,
    Color? sidebarSelected,
    Color? sidebarIndicator,
    Color? primaryHover,
    Color? textOnPage,
    Color? secondaryTextOnPage,
    Color? overlayBackground,
    Color? dialogBorder,
    Color? textFieldFill,
    Color? textFieldBorder,
    Color? progressTrack,
    Color? progressFill,
    Color? chipBackground,
    Color? chipText,
    Color? success,
    Color? warning,
    Color? logoTile,
    List<Color>? avatarColors,
    Color? statusToDoBackground,
    Color? statusToDoText,
    Color? statusInProgressBackground,
    Color? statusInProgressText,
    Color? statusBlockedBackground,
    Color? statusBlockedText,
    Color? statusCompletedBackground,
    Color? statusCompletedText,
    Color? statusOverdueBackground,
    Color? statusOverdueText,
  }) {
    return AppColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarInactive: sidebarInactive ?? this.sidebarInactive,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      sidebarIndicator: sidebarIndicator ?? this.sidebarIndicator,
      primaryHover: primaryHover ?? this.primaryHover,
      textOnPage: textOnPage ?? this.textOnPage,
      secondaryTextOnPage: secondaryTextOnPage ?? this.secondaryTextOnPage,
      overlayBackground: overlayBackground ?? this.overlayBackground,
      dialogBorder: dialogBorder ?? this.dialogBorder,
      textFieldFill: textFieldFill ?? this.textFieldFill,
      textFieldBorder: textFieldBorder ?? this.textFieldBorder,
      progressTrack: progressTrack ?? this.progressTrack,
      progressFill: progressFill ?? this.progressFill,
      chipBackground: chipBackground ?? this.chipBackground,
      chipText: chipText ?? this.chipText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      logoTile: logoTile ?? this.logoTile,
      avatarColors: avatarColors ?? this.avatarColors,
      statusToDoBackground: statusToDoBackground ?? this.statusToDoBackground,
      statusToDoText: statusToDoText ?? this.statusToDoText,
      statusInProgressBackground:
          statusInProgressBackground ?? this.statusInProgressBackground,
      statusInProgressText: statusInProgressText ?? this.statusInProgressText,
      statusBlockedBackground:
          statusBlockedBackground ?? this.statusBlockedBackground,
      statusBlockedText: statusBlockedText ?? this.statusBlockedText,
      statusCompletedBackground:
          statusCompletedBackground ?? this.statusCompletedBackground,
      statusCompletedText: statusCompletedText ?? this.statusCompletedText,
      statusOverdueBackground:
          statusOverdueBackground ?? this.statusOverdueBackground,
      statusOverdueText: statusOverdueText ?? this.statusOverdueText,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      sidebar: l(sidebar, other.sidebar),
      sidebarBorder: l(sidebarBorder, other.sidebarBorder),
      sidebarHover: l(sidebarHover, other.sidebarHover),
      sidebarInactive: l(sidebarInactive, other.sidebarInactive),
      sidebarSelected: l(sidebarSelected, other.sidebarSelected),
      sidebarIndicator: l(sidebarIndicator, other.sidebarIndicator),
      primaryHover: l(primaryHover, other.primaryHover),
      textOnPage: l(textOnPage, other.textOnPage),
      secondaryTextOnPage: l(secondaryTextOnPage, other.secondaryTextOnPage),
      overlayBackground: l(overlayBackground, other.overlayBackground),
      dialogBorder: l(dialogBorder, other.dialogBorder),
      textFieldFill: l(textFieldFill, other.textFieldFill),
      textFieldBorder: l(textFieldBorder, other.textFieldBorder),
      progressTrack: l(progressTrack, other.progressTrack),
      progressFill: l(progressFill, other.progressFill),
      chipBackground: l(chipBackground, other.chipBackground),
      chipText: l(chipText, other.chipText),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      logoTile: l(logoTile, other.logoTile),
      avatarColors: t < 0.5 ? avatarColors : other.avatarColors,
      statusToDoBackground: l(statusToDoBackground, other.statusToDoBackground),
      statusToDoText: l(statusToDoText, other.statusToDoText),
      statusInProgressBackground: l(
        statusInProgressBackground,
        other.statusInProgressBackground,
      ),
      statusInProgressText: l(statusInProgressText, other.statusInProgressText),
      statusBlockedBackground: l(
        statusBlockedBackground,
        other.statusBlockedBackground,
      ),
      statusBlockedText: l(statusBlockedText, other.statusBlockedText),
      statusCompletedBackground: l(
        statusCompletedBackground,
        other.statusCompletedBackground,
      ),
      statusCompletedText: l(statusCompletedText, other.statusCompletedText),
      statusOverdueBackground: l(
        statusOverdueBackground,
        other.statusOverdueBackground,
      ),
      statusOverdueText: l(statusOverdueText, other.statusOverdueText),
    );
  }
}

/// Convenience accessor: `Theme.of(context).appColors`.
extension AppColorsX on ThemeData {
  AppColors get appColors => extension<AppColors>()!;
}

/// Draws a single 1px line along the bottom edge only, used to give the
/// AppBar (and the sidebar's inner edge) a border without adding one on all
/// four sides.
class _EdgeBorderShape extends ShapeBorder {
  const _EdgeBorderShape({required this.color, this.width = 1});

  final Color color;
  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect.deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    canvas.drawLine(
      Offset(rect.left, rect.bottom - width / 2),
      Offset(rect.right, rect.bottom - width / 2),
      paint,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      _EdgeBorderShape(color: color, width: width * t);
}

class AppTheme {
  AppTheme._();

  static final lightTheme = _build(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppPalette.primaryLight,
      onPrimary: Colors.white,
      secondary: AppPalette.accentLight,
      onSecondary: Colors.white,
      surface: AppPalette.surfaceLight,
      onSurface: AppPalette.textPrimaryLight,
      onSurfaceVariant: AppPalette.textSecondaryLight,
      surfaceContainer: AppPalette.backgroundLight,
      surfaceContainerHighest: AppPalette.borderLight,
      outline: AppPalette.borderLight,
      outlineVariant: AppPalette.borderLight,
      error: AppPalette.errorLight,
      onError: Colors.white,
    ),
    scaffoldBackground: AppPalette.backgroundLight,
    appColors: AppColors.light,
  );

  static final darkTheme = _build(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppPalette.primaryDark,
      onPrimary: Colors.white,
      secondary: AppPalette.accentDark,
      onSecondary: AppPalette.backgroundDark,
      surface: AppPalette.surfaceDark,
      onSurface: AppPalette.textPrimaryDark,
      onSurfaceVariant: AppPalette.textSecondaryDark,
      surfaceContainer: AppPalette.backgroundDark,
      surfaceContainerHighest: AppPalette.borderDark,
      outline: AppPalette.borderDark,
      outlineVariant: AppPalette.borderDark,
      error: AppPalette.errorDark,
      onError: AppPalette.backgroundDark,
    ),
    scaffoldBackground: AppPalette.backgroundDark,
    appColors: AppColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required AppColors appColors,
  }) {
    // Elevation shadows are pinned to the brand navy instead of the
    // Material default black.
    const shadow = AppPalette.primaryLight;
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    // Not Size.fromHeight: an infinite min width breaks buttons in Rows.
    const buttonMinSize = Size(64, 48);
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    final fieldRadius = BorderRadius.circular(10);

    // Disabled buttons must look disabled (e.g. Create Account until the
    // password meets the policy).
    Color filledBackground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.surfaceContainerHighest;
      }
      return states.contains(WidgetState.hovered)
          ? appColors.primaryHover
          : colorScheme.primary;
    }

    Color filledForeground(Set<WidgetState> states) =>
        states.contains(WidgetState.disabled)
        ? colorScheme.onSurfaceVariant
        : colorScheme.onPrimary;

    final filledStyle = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith(filledForeground),
      backgroundColor: WidgetStateProperty.resolveWith(filledBackground),
      minimumSize: const WidgetStatePropertyAll(buttonMinSize),
      shape: const WidgetStatePropertyAll(buttonShape),
      textStyle: const WidgetStatePropertyAll(buttonText),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      shadowColor: shadow,
      dividerTheme: DividerThemeData(color: colorScheme.outline, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: appColors.sidebar,
        foregroundColor: appColors.sidebarSelected,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: _EdgeBorderShape(color: appColors.sidebarBorder),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow.withValues(alpha: 0.25),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: appColors.overlayBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: appColors.dialogBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: appColors.overlayBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: appColors.dialogBorder),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(appColors.overlayBackground),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(
            BorderSide(color: appColors.dialogBorder),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(appColors.overlayBackground),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(
            BorderSide(color: appColors.dialogBorder),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.textFieldFill,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: appColors.textFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: appColors.textFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.secondary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: appColors.progressFill,
        linearTrackColor: appColors.progressTrack,
        circularTrackColor: appColors.progressTrack,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: appColors.sidebar,
        indicatorColor: appColors.sidebarIndicator,
        selectedIconTheme: IconThemeData(color: appColors.sidebarSelected),
        selectedLabelTextStyle: TextStyle(color: appColors.sidebarSelected),
        unselectedIconTheme: IconThemeData(color: appColors.sidebarInactive),
        unselectedLabelTextStyle: TextStyle(color: appColors.sidebarInactive),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: appColors.sidebar,
        indicatorColor: appColors.sidebarIndicator,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? appColors.sidebarSelected
                : appColors.sidebarInactive,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? appColors.sidebarSelected
                : appColors.sidebarInactive,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        hoverColor: appColors.primaryHover,
        extendedTextStyle: buttonText,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.onSurface),
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          minimumSize: const WidgetStatePropertyAll(buttonMinSize),
          shape: const WidgetStatePropertyAll(buttonShape),
          textStyle: const WidgetStatePropertyAll(buttonText),
          side: WidgetStatePropertyAll(BorderSide(color: colorScheme.outline)),
        ),
      ),
      // Links ("Forgot password?", "Back to login") use the accent.
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colorScheme.onSurfaceVariant
                : colorScheme.secondary,
          ),
        ),
      ),
      extensions: [appColors],
    );
  }
}
