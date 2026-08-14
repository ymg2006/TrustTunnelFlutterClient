import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:window_manager/window_manager.dart';

final class WindowsAppWindowController with WindowListener implements AppWindowController {
  static const MethodChannel _mainWindowChannel = MethodChannel('trusttunnel/windows_main_window');

  bool _isConfigured = false;
  bool _isHidingWindow = false;

  WindowsAppWindowController()
    : assert(
        defaultTargetPlatform == TargetPlatform.windows,
        'WindowsAppWindowController is only supported on Windows',
      );

  @override
  Future<void> showMainWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hideMainWindow() async {
    if (_isHidingWindow) {
      return;
    }

    _isHidingWindow = true;
    try {
      await windowManager.setSkipTaskbar(true);
      await windowManager.hide();
    } finally {
      _isHidingWindow = false;
    }
  }

  @override
  Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  }) async {
    final shouldShowMainWindowOnLaunch = await _shouldShowMainWindowOnLaunch();

    await windowManager.ensureInitialized();
    if (!_isConfigured) {
      windowManager.addListener(this);
      _isConfigured = true;
    }
    await windowManager.setPreventClose(true);

    final display = await screenRetriever.getPrimaryDisplay();
    final visibleSize = display.visibleSize ?? display.size;
    final defaultSize = Size(
      _clampWindowDimension(
        defaultDimension: defaultWindowSize.width,
        minimumDimension: minimumWindowSize.width,
        visibleDimension: visibleSize.width,
      ),
      _clampWindowDimension(
        defaultDimension: defaultWindowSize.height,
        minimumDimension: minimumWindowSize.height,
        visibleDimension: visibleSize.height,
      ),
    );
    final windowOptions = isDebugMode
        ? WindowOptions(
            center: true,
            size: defaultSize,
          )
        : WindowOptions(
            center: true,
            minimumSize: minimumWindowSize,
            size: defaultSize,
          );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        if (!shouldShowMainWindowOnLaunch) {
          await windowManager.setSkipTaskbar(true);

          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showMainWindow();
        });
      },
    );
  }

  @override
  void onWindowClose() {
    unawaited(hideMainWindow());
  }

  @override
  void onWindowMinimize() {
    unawaited(hideMainWindow());
  }

  Future<bool> _shouldShowMainWindowOnLaunch() async =>
      await _mainWindowChannel.invokeMethod<bool>('shouldShowMainWindowOnLaunch') ?? true;

  double _clampWindowDimension({
    required double defaultDimension,
    required double minimumDimension,
    required double visibleDimension,
  }) => defaultDimension
      .clamp(
        minimumDimension,
        math.max(minimumDimension, visibleDimension),
      )
      .toDouble();
}
