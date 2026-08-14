import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/observers/logging_navigator_observer.dart';
import 'package:trusttunnel/common/theme/app_theme_mode_controller.dart';
import 'package:trusttunnel/feature/app/widgets/app_system_ui_shell.dart';
import 'package:trusttunnel/feature/navigation/navigation_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  AppThemeModeController? _themeModeController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeModeController ??= AppThemeModeController(
      preferences: context.dependencyFactory.sharedPreferences,
    );
  }

  @override
  Widget build(BuildContext context) => AppThemeModeScope(
    controller: _themeModeController!,
    child: ListenableBuilder(
      listenable: _themeModeController!,
      builder: (context, _) => MaterialApp(
        theme: context.dependencyFactory.lightThemeData,
        darkTheme: context.dependencyFactory.darkThemeData,
        themeMode: _themeModeController!.themeMode,
        navigatorObservers: [
          LoggingNavigatorObserver(
            navigatorName: 'root',
          ),
        ],
        home: Builder(
          builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: context.colors.background,
              statusBarBrightness: context.theme.brightness,
            ),
            child: const AppSystemUIShell(
              child: NavigationScreen(),
            ),
          ),
        ),
        title: AppConstants.appName,
        locale: Localization.defaultLocale,
        localizationsDelegates: Localization.localizationDelegates,
        supportedLocales: Localization.supportedLocales,
      ),
    ),
  );

  @override
  void dispose() {
    _themeModeController?.dispose();
    super.dispose();
  }
}
