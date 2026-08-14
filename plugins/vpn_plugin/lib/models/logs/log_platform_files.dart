import 'package:flutter/foundation.dart';

class LogPlatformFiles {
  final List<String> value;

  const LogPlatformFiles._(this.value);

  factory LogPlatformFiles.platform(TargetPlatform platform) {
    final fileNames = switch (platform) {
      TargetPlatform.android => const ['vpn'],
      TargetPlatform.iOS || TargetPlatform.macOS => const ['app', 'extension'],
      TargetPlatform.windows || TargetPlatform.linux => const ['vpn'],
      TargetPlatform.fuchsia => const <String>[],
    };

    return LogPlatformFiles._(fileNames);
  }
}
