import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/data/datasources/open_main_window_on_login_datasource.dart';

class OpenMainWindowOnLoginDataSourceImpl implements OpenMainWindowOnLoginDataSource {
  static const _macOSMainWindowChannel = MethodChannel('trusttunnel/macos_main_window');
  static const _windowsMainWindowChannel = MethodChannel('trusttunnel/windows_main_window');
  static const _linuxMainWindowChannel = MethodChannel('trusttunnel/linux_main_window');

  @override
  Future<bool> isEnabled() async => await _mainWindowChannel.invokeMethod<bool>('getOpenMainWindowOnLogin') ?? false;

  @override
  Future<void> setEnabled(bool enabled) async {
    await _mainWindowChannel.invokeMethod<void>(
      'setOpenMainWindowOnLogin',
      <String, Object?>{
        'enabled': enabled,
      },
    );
  }

  MethodChannel get _mainWindowChannel => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => _macOSMainWindowChannel,
    TargetPlatform.windows => _windowsMainWindowChannel,
    TargetPlatform.linux => _linuxMainWindowChannel,
    _ => _throwUnsupportedError(),
  };

  Never _throwUnsupportedError() => throw UnsupportedError(
    'OpenMainWindowOnLoginDataSource currently is only supported on macOS, Windows, and Linux',
  );
}
