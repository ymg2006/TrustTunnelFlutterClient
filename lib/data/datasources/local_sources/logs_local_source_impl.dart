import 'dart:convert';
import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_local_source.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';
import 'package:vpn_plugin/models/logs/log_platform_files.dart';
import 'package:vpn_plugin/vpn_plugin.dart';

final class LogsLocalSourceImpl implements LogsLocalSource {
  static const _logTempKey = '_logTempKey';

  final FileLogAppender _logAppender;
  final AppStateLoggingDataSource _appStateLoggingDataSource;
  final FilePicker _filePicker;
  final VpnPlugin _vpnPlugin;
  final SharedPreferences _sharedPreferences;

  LogsLocalSourceImpl({
    required FileLogAppender logAppender,
    required AppStateLoggingDataSource appStateLoggingDataSource,
    required FilePicker filePicker,
    required VpnPlugin vpnPlugin,
    required SharedPreferences sharedPreferences,
  }) : _logAppender = logAppender,
       _appStateLoggingDataSource = appStateLoggingDataSource,
       _vpnPlugin = vpnPlugin,
       _sharedPreferences = sharedPreferences,
       _filePicker = filePicker;

  @override
  Future<ExportLogsArchive> createArchive() async {
    final logFiles = <String, Uint8List>{};
    List<String> logPaths = const [];

    try {
      logPaths = await _vpnPlugin.fetchLogsPath();
    } catch (error, stackTrace) {
      logFiles['vpn_logs_export_error.log'] = utf8.encode(
        'Failed to export VPN logs.${Platform.lineTerminator}'
        'Error: $error${Platform.lineTerminator}'
        'Stack trace:${Platform.lineTerminator}$stackTrace',
      );
    }

    for (final group in LogPlatformFiles.platform(defaultTargetPlatform).value) {
      final regex = RegExp(r'.*' + group + r'(\.\d+)?\.log');
      final selectedPaths = logPaths.where(regex.hasMatch).toList();

      List<String> lines = const [];
      try {
        lines = selectedPaths.isEmpty
            ? <String>[]
            : (await _vpnPlugin.exportLogsFor(selectedPaths)).map((r) => r.toString()).toList();
      } catch (error, stackTrace) {
        lines = [
          'Failed to read $group logs.',
          'Error: $error',
          'Stack trace:',
          stackTrace.toString(),
        ];
      }

      logFiles['$group.log'] = utf8.encode(lines.join(Platform.lineTerminator));
    }

    try {
      final snapshot = await _appStateLoggingDataSource.collectSnapshot();
      logFiles['app_state.log'] = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      );
    } catch (error, stackTrace) {
      logFiles['app_state_error.log'] = utf8.encode(
        'Failed to collect app state.${Platform.lineTerminator}'
        'Error: $error${Platform.lineTerminator}'
        'Stack trace:${Platform.lineTerminator}$stackTrace',
      );
    }

    return ExportLogsArchive(
      data: _archive(logFiles),
      name: _generateArchiveName(),
    );
  }

  @override
  Future<String?> pickFilePath({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    ExportFileType type = ExportFileType.any,
    List<String>? allowedExtensions,
    Uint8List? data,
  }) async {
    final isMobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };

    final path = await _filePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      initialDirectory: initialDirectory,
      type: type.filePickerType,
      allowedExtensions: allowedExtensions,
      bytes: isMobile ? data : null,
    );

    return path;
  }

  @override
  Future<String> saveRawFile({
    required Uint8List data,
    required String path,
    bool temporary = true,
  }) async {
    final file = await File(path).create(recursive: true);
    await file.writeAsBytes(data, mode: FileMode.writeOnly, flush: true);
    if (!temporary) {
      return path;
    }

    final tempLogs = _sharedPreferences.getStringList(_logTempKey);
    await _sharedPreferences.setStringList(_logTempKey, [...?tempLogs, path]);

    return path;
  }

  @override
  Future<String> saveExportFile({
    required Uint8List data,
    required String path,
  }) async {
    final exportPath = _withZipExtension(path);
    final file = await File(exportPath).create(recursive: true);
    await file.writeAsBytes(data, mode: FileMode.writeOnly, flush: true);
    final savedLength = await file.length();

    if (savedLength != data.length) {
      throw FileSystemException(
        'Exported log archive was not written completely',
        exportPath,
      );
    }

    return exportPath;
  }

  @override
  Future<void> deleteLogs() => Future.wait([
    clearTempFiles(),
    _logAppender.clearAllLogs(),
    _vpnPlugin.clearLogs(),
  ]);

  @override
  Future<void> clearTempFiles() async {
    final tempFiles = _sharedPreferences.getStringList(_logTempKey)?.map((path) => File(path)) ?? [];

    for (final file in tempFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _sharedPreferences.remove(_logTempKey);

    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      // This method is not available on desktop platforms (only Android and iOS)
      await _filePicker.clearTemporaryFiles();
    }
  }

  String _generateArchiveName() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll(RegExp(r'\..*'), '');

    return 'trusttunnel_${defaultTargetPlatform.name}_logs_$timestamp.zip';
  }

  String _withZipExtension(String path) {
    if (path.toLowerCase().endsWith('.zip')) {
      return path;
    }

    return '$path.zip';
  }

  Uint8List _archive(Map<String, Uint8List> files) {
    final archive = Archive();

    for (final entry in files.entries) {
      archive.addFile(
        ArchiveFile(
          entry.key,
          entry.value.length,
          entry.value,
        ),
      );
    }

    return Uint8List.fromList(
      ZipEncoder().encode(
        archive,
        level: DeflateLevel.bestCompression,
      ),
    );
  }
}

extension on ExportFileType {
  FileType get filePickerType => switch (this) {
    ExportFileType.any => FileType.any,
    ExportFileType.custom => FileType.custom,
  };
}
