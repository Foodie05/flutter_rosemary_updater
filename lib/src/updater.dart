import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'model/update_request.dart';
import 'model/update_receive.dart';
import 'script_runner.dart';
import 'utils.dart';

class UpdaterConfig {
  final String apiBaseUrl;
  final String appName;
  final String appPasswd; // Assuming these are needed for request
  final String betaPasswd;
  final int appVersion;
  final int resVersion;
  final String? downloadDir; // Optional, default to app doc dir

  UpdaterConfig({
    required this.apiBaseUrl,
    required this.appName,
    required this.appPasswd,
    required this.betaPasswd,
    required this.appVersion,
    required this.resVersion,
    this.downloadDir,
  });
}

class UpdateStatus {
  final bool checking;
  final bool downloading;
  final bool installing;
  final bool success;
  final String? error;
  final int progress;
  final String message;

  UpdateStatus({
    this.checking = false,
    this.downloading = false,
    this.installing = false,
    this.success = false,
    this.error,
    this.progress = 0,
    this.message = '',
  });

  UpdateStatus copyWith({
    bool? checking,
    bool? downloading,
    bool? installing,
    bool? success,
    String? error,
    int? progress,
    String? message,
  }) {
    return UpdateStatus(
      checking: checking ?? this.checking,
      downloading: downloading ?? this.downloading,
      installing: installing ?? this.installing,
      success: success ?? this.success,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      message: message ?? this.message,
    );
  }
}

class RosemaryUpdater {
  final UpdaterConfig config;
  final Dio _dio = Dio();

  RosemaryUpdater(this.config);

  Future<UpdateReceive?> checkUpdate() async {
    try {
      final requestData = UpdateRequest(
        appName: config.appName,
        appPasswd: config.appPasswd,
        appVersion: config.appVersion,
        betaPasswd: config.betaPasswd,
        resVersion: config.resVersion,
        platform: _currentPlatform(),
      );

      // Assuming API endpoint structure based on zion
      // Need to verify exact endpoint path.
      // In zion/lib/controllers/update_controller.dart, it calls UpgradeData().checkUpdate
      // In zion/lib/upgrade/upgrade_data.dart:
      // final response = await http.post(Uri.parse('${GlobalValue.apiBaseUrl}/api/update_check'), ...
      
      final url = '${config.apiBaseUrl}/update';
      final data = requestData.toJson();
      
      debugPrintLog('Checking update from: $url');
      debugPrintLog('Request Body: $data');

      final response = await _dio.post(
        url,
        data: data,
      );

      debugPrintLog('Response Status: ${response.statusCode}');
      debugPrintLog('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        return UpdateReceive.fromJson(response.data);
      } else {
        debugPrintLog('Check update failed: ${response.statusCode}');
        throw Exception('Check update failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrintLog('Check update error: $e');
      rethrow;
    }
  }

  Future<void> runUpdate({
    required UpdateReceive updateInfo,
    required void Function(UpdateStatus status) onStatusChanged,
  }) async {
    if (updateInfo.resUpgrade) {
      await _runResUpdate(updateInfo, onStatusChanged);
    }

    if (updateInfo.appUpgrade) {
      await _runAppUpdate(updateInfo, onStatusChanged);
    }
  }

  Future<void> _runAppUpdate(
    UpdateReceive updateInfo,
    void Function(UpdateStatus status) onStatusChanged,
  ) async {
    if (updateInfo.appUpgradeUrl.isEmpty) {
      onStatusChanged(UpdateStatus(
        error: 'App update URL is empty',
        success: false,
      ));
      return;
    }

    try {
      final installKind = updateInfo.appUpgradeInstallKind.toLowerCase();
      if (installKind == 'appstore' || installKind == 'testflight') {
        onStatusChanged(UpdateStatus(
          installing: true,
          message: 'Opening update channel...',
          progress: 100,
        ));
        await _launchExternalUpdateUrl(updateInfo, onStatusChanged);
        return;
      }

      onStatusChanged(UpdateStatus(
        downloading: true,
        message: 'Downloading app update...',
        progress: 0,
      ));

      String downloadPath;
      if (config.downloadDir != null) {
        downloadPath = config.downloadDir!;
      } else {
        // Use external storage directory for Android if possible to avoid strict file permission issues
        // or temporary directory
        if (Platform.isAndroid) {
          final extDir = await getExternalStorageDirectory();
          downloadPath = extDir?.path ?? (await getTemporaryDirectory()).path;
        } else {
          final tempDir = await getTemporaryDirectory();
          downloadPath = tempDir.path;
        }
      }

      final fileName = _buildInstallerFileName(updateInfo);
      final filePath = path.join(downloadPath, fileName);

      // Download APK
      await _dio.download(
        updateInfo.appUpgradeUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            int progress = (received / total * 100).toInt();
            onStatusChanged(UpdateStatus(
              downloading: true,
              progress: progress,
              message: 'Downloading app update...',
            ));
          }
        },
      );

      onStatusChanged(UpdateStatus(
        installing: true,
        message: 'Installing app update...',
        progress: 100,
      ));

      await _launchInstaller(
        filePath: filePath,
        updateInfo: updateInfo,
        onStatusChanged: onStatusChanged,
      );
    } catch (e) {
      onStatusChanged(UpdateStatus(
        error: 'App update failed: $e',
        success: false,
      ));
    }
  }

  Future<void> _runResUpdate(
    UpdateReceive updateInfo,
    void Function(UpdateStatus status) onStatusChanged,
  ) async {
    onStatusChanged(
        UpdateStatus(downloading: true, message: 'Downloading resources...'));

    try {
      String downloadPath;
      if (config.downloadDir != null) {
        downloadPath = config.downloadDir!;
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        downloadPath = docDir.path;
      }

      final zipPath = path.join(downloadPath, 'update_temp.zip');

      // Download
      await _dio.download(
        updateInfo.resUpgradeUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            int progress = (received / total * 100).toInt();
            onStatusChanged(UpdateStatus(
                downloading: true,
                progress: progress,
                message: 'Downloading resources...'));
          }
        },
      );

      onStatusChanged(
          UpdateStatus(installing: true, message: 'Installing resources...'));

      // Unzip
      final scriptRunner = ScriptRunner(
          appVersion: config.appVersion,
          onMessage: (msg) {
            // Relay script messages?
            debugPrintLog('Script says: $msg');
          });

      // We need to unzip to a temp dir first to find the script?
      // Or does the script runner handle unzipping?
      // In Zion UpgradeData:
      // 1. Download to update.zip
      // 2. Unzip to 'update_temp'
      // 3. Run 'update_temp/update.rp'

      final updateTempDir = path.join(downloadPath, 'update_temp');
      final updateTempDirObj = Directory(updateTempDir);
      if (await updateTempDirObj.exists()) {
        await updateTempDirObj.delete(recursive: true);
      }
      await updateTempDirObj.create(recursive: true);

      // Unzip manually or use script?
      // Zion uses global_functions.dart unzipFile.
      // We can use our ScriptRunner unzip if we want, or just archive directly.
      // Let's use ScriptRunner's unzip logic but called directly or just standard unzip.
      // Actually ScriptRunner has 'unzip' command.
      // But we need to bootstrap.

      bool unzipResult =
          scriptRunner.unzip([zipPath, updateTempDir], progressCallback: (p) {
        onStatusChanged(UpdateStatus(
            installing: true, progress: p, message: 'Unzipping resources...'));
      });

      if (!unzipResult) {
        throw Exception('Failed to unzip update package');
      }

      // Run script
      final scriptPath = path.join(updateTempDir, 'update.rp');
      if (!await File(scriptPath).exists()) {
        throw Exception('Update script not found');
      }

      bool scriptResult = await scriptRunner.fileScript(scriptPath,
          initSetDir: downloadPath, // or where? Zion passes initSetDir.
          // In Zion UpgradeData: ResPatchFunc().shellScript(..., initSetDir: appDocDir.path)
          // Wait, if initSetDir is appDocDir, then relative paths in script are relative to appDocDir.
          progressCallback: (total, sub) {
        onStatusChanged(UpdateStatus(
            installing: true, progress: total, message: 'Applying patch...'));
      });

      if (scriptResult) {
        // Clean up
        await File(zipPath).delete();
        await updateTempDirObj.delete(recursive: true);
        onStatusChanged(UpdateStatus(
            success: true, message: 'Update completed successfully'));
      } else {
        throw Exception('Update script failed');
      }
    } catch (e) {
      onStatusChanged(
          UpdateStatus(error: e.toString(), message: 'Update failed'));
    }
  }

  Future<void> _launchInstaller({
    required String filePath,
    required UpdateReceive updateInfo,
    required void Function(UpdateStatus status) onStatusChanged,
  }) async {
    final installKind = updateInfo.appUpgradeInstallKind.toLowerCase();

    if (installKind == 'appstore' || installKind == 'testflight') {
      await _launchExternalUpdateUrl(updateInfo, onStatusChanged);
      return;
    }

    final result = await OpenFile.open(filePath);

    if (result.type != ResultType.done) {
      onStatusChanged(UpdateStatus(
        error: 'Failed to open installer: ${result.message}',
        success: false,
      ));
      return;
    }

    onStatusChanged(UpdateStatus(
      success: true,
      message: _installSuccessMessage(updateInfo),
    ));
  }

  Future<void> launchStoreUpdate({
    required UpdateReceive updateInfo,
    required void Function(UpdateStatus status) onStatusChanged,
  }) async {
    await _launchExternalUpdateUrl(updateInfo, onStatusChanged);
  }

  Future<void> _launchExternalUpdateUrl(
    UpdateReceive updateInfo,
    void Function(UpdateStatus status) onStatusChanged,
  ) async {
    if (updateInfo.appUpgradeUrl.isEmpty) {
      onStatusChanged(UpdateStatus(
        error: 'Update URL is empty',
        success: false,
      ));
      return;
    }

    final uri = Uri.tryParse(updateInfo.appUpgradeUrl);
    if (uri == null) {
      onStatusChanged(UpdateStatus(
        error: 'Invalid update URL',
        success: false,
      ));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      onStatusChanged(UpdateStatus(
        error: 'Failed to open update URL',
        success: false,
      ));
      return;
    }

    onStatusChanged(UpdateStatus(
      success: true,
      message: _installSuccessMessage(updateInfo),
    ));
  }

  String _buildInstallerFileName(UpdateReceive updateInfo) {
    final extension = switch (updateInfo.appUpgradeInstallKind.toLowerCase()) {
      'dmg' => 'dmg',
      'exe' => 'exe',
      'msi' => 'msi',
      _ => 'apk',
    };
    return 'update_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  String _installSuccessMessage(UpdateReceive updateInfo) {
    switch (updateInfo.appUpgradeInstallKind.toLowerCase()) {
      case 'dmg':
        return 'DMG opened. Mount it and drag the app into Applications to finish the update.';
      case 'exe':
      case 'msi':
        return 'Installer opened. Follow the setup wizard to complete the update.';
      case 'appstore':
        final label = updateInfo.appUpgradeStoreLabel.isEmpty
            ? 'the store'
            : updateInfo.appUpgradeStoreLabel;
        return 'Redirected to $label for update installation.';
      case 'testflight':
        return 'Redirected to TestFlight to continue the update.';
      default:
        return 'App update installation started.';
    }
  }

  String _currentPlatform() {
    if (kIsWeb) {
      return 'web';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  }
}
