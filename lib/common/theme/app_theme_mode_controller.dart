import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class AppThemeModeController extends ChangeNotifier {
  static const _storageKey = 'app_theme_mode';

  final SharedPreferences _preferences;

  AppThemeModeController({required SharedPreferences preferences})
    : _preferences = preferences,
      _themeMode = _parse(preferences.getString(_storageKey));

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) {
      return;
    }

    _themeMode = value;
    await _preferences.setString(_storageKey, value.name);
    notifyListeners();
  }

  static ThemeMode _parse(String? value) => ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.system,
  );
}

class AppThemeModeScope extends InheritedNotifier<AppThemeModeController> {
  const AppThemeModeScope({
    super.key,
    required AppThemeModeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeModeController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeModeScope>();
    assert(scope != null, 'AppThemeModeScope is not found in the widget tree');

    return scope!.notifier!;
  }
}
