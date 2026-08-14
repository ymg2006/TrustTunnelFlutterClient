import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/common/theme/light_theme.dart';

class DarkTheme {
  static const _accent = Color(0xFF6AA8E8);
  static const _accentHover = Color(0xFF83B8ED);
  static const _accentPressed = Color(0xFF4E91D5);
  static const _accentDisabled = Color(0x666AA8E8);

  static const _background = Color(0xFF101418);
  static const _backgroundAdditional = Color(0xFF151B21);
  static const _backgroundElevated = Color(0xFF1B232B);
  static const _backgroundSystem = Color(0xFF202A33);
  static const _backgroundSystemHover = Color(0xFF2A3641);
  static const _backgroundSystemPressed = Color(0xFF334252);

  static const _neutralLight = Color(0xFF9BAABC);
  static const _neutralDark = Color(0xFFC7D3E1);
  static const _neutralBlack = Color(0xFFE8EEF6);

  static const _attention = Color(0xFFFFB14A);
  static const _error = Color(0xFFFF6B55);
  static const _transparent = Colors.transparent;
  static const _appSystemTitleBarBackground = Color(0xFF101418);
  static const _appSystemTitleBarTitle = Color(0xFFE8EEF6);

  late final _colors = const CustomColors(
    accent: _accent,
    accentHover: _accentHover,
    accentPressed: _accentPressed,
    accentDisabled: _accentDisabled,
    blend: Color(0x336AA8E8),
    blendHover: Color(0x4D6AA8E8),
    blendPressed: Color(0x666AA8E8),
    attention: _attention,
    attentionHover: Color(0xFFFFC06B),
    attentionPressed: Color(0xFFE89A31),
    attentionDisabled: Color(0x80FFB14A),
    error: _error,
    errorHover: Color(0xFFFF806E),
    errorPressed: Color(0xFFE7533F),
    errorDisabled: Color(0x80FF6B55),
    background: _background,
    backgroundAdditional: _backgroundAdditional,
    backgroundElevated: _backgroundElevated,
    backgroundSystem: _backgroundSystem,
    backgroundSystemHover: _backgroundSystemHover,
    backgroundSystemPressed: _backgroundSystemPressed,
    neutralLight: _neutralLight,
    neutralLightHover: Color(0xFFB0BDCC),
    neutralLightPressed: Color(0xFF8797AA),
    neutralLightDisabled: Color(0x33E8EEF6),
    neutralDark: _neutralDark,
    neutralDarkHover: Color(0xFFD9E3EF),
    neutralDarkPressed: Color(0xFFAEBFD1),
    neutralDarkDisabled: Color(0x4DE8EEF6),
    neutralBlack: _neutralBlack,
    neutralBlackHover: Color(0xFFFFFFFF),
    neutralBlackPressed: Color(0xFFD1DCE8),
    neutralBlackDisabled: Color(0x66E8EEF6),
    specialStaticWhite: Color(0xFFFFFFFF),
    specialStaticWhiteHover: Color(0xFFF6F7F9),
    specialStaticWhitePressed: Color(0xFFE6EAEF),
    specialStaticWhiteDisabled: Color(0x80FFFFFF),
    staticTransparent: _transparent,
    appSystemTitleBarBackground: _appSystemTitleBarBackground,
    appSystemTitleBarTitle: _appSystemTitleBarTitle,
    primary1: Color(0xFF67B279),
    primary2: Color(0xFF5B9F6B),
    primary3: Color(0xFF4E8C5D),
    primary4: Color(0xFFA2D0AD),
    blend1: Color(0x334F8AC4),
    blend2: Color(0x4D4F8AC4),
    blend3: Color(0x664F8AC4),
    orange1: Color(0xFFFFB14A),
    orange2: Color(0xFFFFC06B),
    orange3: Color(0xFFE89A31),
    orange4: Color(0x80FFB14A),
    red1: Color(0xFFFF6B55),
    red2: Color(0xFFFF806E),
    red3: Color(0xFFE7533F),
    red4: Color(0x80FF6B55),
    background1: _background,
    background2: _backgroundAdditional,
    background3: _backgroundSystem,
    gray1: Color(0xFF9BAABC),
    gray2: Color(0xFFC7D3E1),
    gray3: Color(0xFFE8EEF6),
    gray4: Color(0xFF334252),
    contrast1: Color(0xFFE8EEF6),
    contrast2: Color(0xFFC7D3E1),
    contrast3: Color(0xFF9BAABC),
    contrast4: Color(0xFF8797AA),
    staticBlack1: Color(0xFF0A0A0A),
    staticBlack2: Color(0xFF1F1F1F),
    staticBlack3: Color(0xFF3D3D3D),
    staticWhite: Color(0xFFF6F6F6),
    purple1: Color(0xFFC096C7),
    purple2: Color(0xFFA870B2),
    purple3: Color(0xFF9F61AA),
    purple4: Color(0xFFD8B4DE),
    accentMainDefault: _accent,
  );

  ThemeData get data {
    final base = LightTheme().data;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      surface: _background,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: _neutralBlack,
      displayColor: _neutralBlack,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      primaryColor: _accent,
      scaffoldBackgroundColor: _background,
      canvasColor: _background,
      cardColor: _backgroundElevated,
      hoverColor: _transparent,
      focusColor: _transparent,
      textTheme: textTheme,
      iconTheme: base.iconTheme.copyWith(color: _neutralBlack),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: _backgroundElevated,
        hoverColor: _backgroundSystemHover,
        iconColor: _neutralDark,
        prefixIconColor: _neutralDark,
        suffixIconColor: _neutralDark,
        labelStyle: textTheme.bodySmall?.copyWith(color: _neutralDark),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: _neutralDark),
        hintStyle: textTheme.bodyLarge?.copyWith(color: _neutralLight),
        helperStyle: textTheme.bodySmall?.copyWith(color: _neutralLight),
        counterStyle: textTheme.bodySmall?.copyWith(color: _neutralLight),
        errorStyle: textTheme.bodySmall?.copyWith(color: _error),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _neutralLight),
        ),
        disabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0x4DE8EEF6)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _accent, width: 3),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _error, width: 3),
        ),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accent;
          }
          if (states.contains(WidgetState.disabled)) {
            return _neutralLight.withValues(alpha: 0.45);
          }

          return _neutralDark;
        }),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: _neutralBlack,
        iconColor: _neutralDark,
        titleTextStyle: textTheme.titleSmall?.copyWith(color: _neutralBlack),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: _neutralLight),
      ),
      switchTheme: base.switchTheme.copyWith(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accent;
          }

          return _backgroundSystemPressed;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return _neutralDark;
        }),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: _neutralBlack,
        backgroundColor: _transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _backgroundElevated,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: const Color(0x33E8EEF6),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: _backgroundSystem,
        indicatorColor: const Color(0x4D6AA8E8),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: _backgroundSystem,
        indicatorColor: const Color(0x336AA8E8),
        selectedLabelTextStyle: textTheme.labelMedium,
        unselectedLabelTextStyle: textTheme.labelMedium,
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: _backgroundElevated,
        surfaceTintColor: _transparent,
        textStyle: textTheme.bodyLarge,
      ),
      menuBarTheme: const MenuBarThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_backgroundElevated),
          surfaceTintColor: WidgetStatePropertyAll(_transparent),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_backgroundElevated),
          surfaceTintColor: WidgetStatePropertyAll(_transparent),
        ),
      ),
      dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
        textStyle: textTheme.bodyLarge,
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: _backgroundElevated,
          labelStyle: textTheme.bodySmall,
          hintStyle: textTheme.bodyLarge?.copyWith(color: _neutralLight),
        ),
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(_backgroundElevated),
          surfaceTintColor: WidgetStatePropertyAll(_transparent),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: _backgroundElevated,
        contentTextStyle: textTheme.bodyMedium,
        closeIconColor: _neutralBlack,
      ),
      extensions: [
        _colors,
        ...base.extensions.values.where((extension) => extension is! CustomColors),
      ],
    );
  }
}
