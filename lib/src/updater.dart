import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_file_plus/open_file_plus.dart';
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
      );

      // Assuming API endpoint structure based on zion
      // Need to verify exact endpoint path. 
      // In zion/lib/controllers/update_controller.dart, it calls UpgradeData().checkUpdate
      // In zion/lib/upgrade/upgrade_data.dart: 
      // final response = await http.post(Uri.parse('${GlobalValue.apiBaseUrl}/api/update_check'), ...
      
      final response = await _dio.post(
        '${config.apiBaseUrl}/api/update_check',
        data: requestData.toJson(),
      );

      if (response.statusCode == 200) {
        return UpdateReceive.fromJson(response.data);
      } else {
        debugPrintLog('Check update failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrintLog('Check update error: $e');
      return null;
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

      final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.apk';
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

      // Install APK
      final result = await OpenFile.open(filePath);
      
      if (result.type == ResultType.done) {
        onStatusChanged(UpdateStatus(
          success: true,
          message: 'App update installation started',
        ));
      } else {
         onStatusChanged(UpdateStatus(
          error: 'Failed to open APK: ${result.message}',
          success: false,
        ));
      }

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
    onStatusChanged(UpdateStatus(downloading: true, message: 'Downloading resources...'));

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
            onStatusChanged(UpdateStatus(downloading: true, progress: progress, message: 'Downloading resources...'));
          }
        },
      );

      onStatusChanged(UpdateStatus(installing: true, message: 'Installing resources...'));

      // Unzip
      final scriptRunner = ScriptRunner(
        appVersion: config.appVersion,
        onMessage: (msg) {
           // Relay script messages?
           debugPrintLog('Script says: $msg');
        }
      );
      
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
      
      bool unzipResult = scriptRunner.unzip(
        [zipPath, updateTempDir], 
        progressCallback: (p) {
           onStatusChanged(UpdateStatus(installing: true, progress: p, message: 'Unzipping resources...'));
        }
      );
      
      if (!unzipResult) {
        throw Exception('Failed to unzip update package');
      }

      // Run script
      final scriptPath = path.join(updateTempDir, 'update.rp');
      if (!await File(scriptPath).exists()) {
         throw Exception('Update script not found');
      }

      bool scriptResult = await scriptRunner.fileScript(
        scriptPath,
        initSetDir: downloadPath, // or where? Zion passes initSetDir. 
        // In Zion UpgradeData: ResPatchFunc().shellScript(..., initSetDir: appDocDir.path)
        // Wait, if initSetDir is appDocDir, then relative paths in script are relative to appDocDir.
        progressCallback: (total, sub) {
          onStatusChanged(UpdateStatus(installing: true, progress: total, message: 'Applying patch...'));
        }
      );

      if (scriptResult) {
        // Clean up
        await File(zipPath).delete();
        await updateTempDirObj.delete(recursive: true);
        onStatusChanged(UpdateStatus(success: true, message: 'Update completed successfully'));
      } else {
        throw Exception('Update script failed');
      }

    } catch (e) {
      onStatusChanged(UpdateStatus(error: e.toString(), message: 'Update failed'));
    }
  }
}
