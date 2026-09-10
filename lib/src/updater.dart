import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'model/update_request.dart';
import 'model/update_receive.dart';
import 'model/latest_release.dart';
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
  final UpdateLogCallback? logger;
  final BetaValidationMode betaValidationMode;
  final SignedUpdateConfig? signedUpdateConfig;

  UpdaterConfig({
    required this.apiBaseUrl,
    required this.appName,
    required this.appPasswd,
    required this.betaPasswd,
    required this.appVersion,
    required this.resVersion,
    this.downloadDir,
    this.logger,
    this.betaValidationMode = BetaValidationMode.fixedPassword,
    this.signedUpdateConfig,
  });
}

enum BetaValidationMode {
  fixedPassword,
  serverSigned,
}

class SignedUpdateConfig {
  final String brokerEndpoint;
  final String? authToken;
  final String? userEmail;
  final Map<String, String>? headers;
  final int ttlSeconds;
  final int maxUses;

  const SignedUpdateConfig({
    required this.brokerEndpoint,
    this.authToken,
    this.userEmail,
    this.headers,
    this.ttlSeconds = 300,
    this.maxUses = 1,
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
  final int receivedBytes;
  final int totalBytes;

  UpdateStatus({
    this.checking = false,
    this.downloading = false,
    this.installing = false,
    this.success = false,
    this.error,
    this.progress = 0,
    this.message = '',
    this.receivedBytes = 0,
    this.totalBytes = 0,
  });

  UpdateStatus copyWith({
    bool? checking,
    bool? downloading,
    bool? installing,
    bool? success,
    String? error,
    int? progress,
    String? message,
    int? receivedBytes,
    int? totalBytes,
  }) {
    return UpdateStatus(
      checking: checking ?? this.checking,
      downloading: downloading ?? this.downloading,
      installing: installing ?? this.installing,
      success: success ?? this.success,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class RosemaryUpdater {
  static const int _resDownloadWeight = 80;
  static const int _resUnzipWeight = 10;
  static const int _resScriptWeight = 10;
  static const int _resPrimaryUnzipWeight = 5;
  static const int _resLegacyUnzipWeight = 5;
  final UpdaterConfig config;
  final Dio _dio = Dio();
  int _lastAppDownloadLogProgress = -1;
  int _lastResDownloadLogProgress = -1;
  int _lastResScriptLogProgress = -1;

  RosemaryUpdater(this.config);

  Future<LatestStableAppRelease?> fetchLatestStableAppRelease({
    String? appName,
  }) async {
    try {
      final response = await _dio.get(
        '${config.apiBaseUrl}/update/latest-app',
        queryParameters: {'appName': appName ?? config.appName},
        options: Options(validateStatus: (status) => status != null),
      );
      if (response.data is Map) {
        return LatestStableAppRelease.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return null;
    } catch (e, stackTrace) {
      await _logError(
        'RosemaryUpdater.fetchLatestStableAppRelease',
        '获取最新稳定版应用信息异常',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<LatestStableResourceRelease?> fetchLatestStableResourceRelease({
    String? appName,
  }) async {
    try {
      final response = await _dio.get(
        '${config.apiBaseUrl}/update/latest-res',
        queryParameters: {'appName': appName ?? config.appName},
        options: Options(validateStatus: (status) => status != null),
      );
      if (response.data is Map) {
        return LatestStableResourceRelease.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
      return null;
    } catch (e, stackTrace) {
      await _logError(
        'RosemaryUpdater.fetchLatestStableResourceRelease',
        '获取最新稳定版资源信息异常',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

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

      await _logInfo(
        'RosemaryUpdater.checkUpdate',
        '开始检查更新',
        metadata: {
          'apiBaseUrl': config.apiBaseUrl,
          'appName': config.appName,
          'appVersion': config.appVersion,
          'resVersion': config.resVersion,
          'platform': _currentPlatform(),
        },
      );
      Response response;
      if (config.betaValidationMode == BetaValidationMode.serverSigned) {
        final signedCfg = config.signedUpdateConfig;
        if (signedCfg == null) {
          await _logWarning(
            'RosemaryUpdater.checkUpdate',
            'Signed mode requires signedUpdateConfig',
          );
          return null;
        }
        final signedHeaders = <String, String>{
          'Content-Type': 'application/json',
          ...?signedCfg.headers,
        };
        if (signedCfg.authToken != null && signedCfg.authToken!.isNotEmpty) {
          signedHeaders['Authorization'] = 'Bearer ${signedCfg.authToken!}';
        }
        try {
          final brokerResp = await _dio.post(
            signedCfg.brokerEndpoint,
            data: {
              'email': signedCfg.userEmail ?? '',
              'payload': requestData.toJson(),
              'ttlSeconds': signedCfg.ttlSeconds,
              'maxUses': signedCfg.maxUses,
            },
            options: Options(headers: signedHeaders),
          );
          final signedUrl = brokerResp.data['signedUrl'] as String? ?? '';
          if (signedUrl.isNotEmpty) {
            response = await _dio.get(signedUrl);
          } else {
            await _logWarning(
              'RosemaryUpdater.checkUpdate',
              'Broker signedUrl empty, fallback to normal update',
            );
            response = await _dio.post(url, data: data);
          }
        } catch (e, stackTrace) {
          await _logWarning(
            'RosemaryUpdater.checkUpdate',
            'Signed update failed, fallback to normal update',
            metadata: {'error': '$e', 'stackTrace': '$stackTrace'},
          );
          response = await _dio.post(url, data: data);
        }
      } else {
        response = await _dio.post(url, data: data);
      }

      debugPrintLog('Response Status: ${response.statusCode}');
      debugPrintLog('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final result = UpdateReceive.fromJson(response.data);
        await _logInfo(
          'RosemaryUpdater.checkUpdate',
          '更新检查完成',
          metadata: {
            'statusCode': response.statusCode,
            'appUpgrade': result.appUpgrade,
            'resUpgrade': result.resUpgrade,
            'appUpgradeUrl': result.appUpgradeUrl,
            'resUpgradeUrl': result.resUpgradeUrl,
          },
        );
        return result;
      } else {
        debugPrintLog('检查更新失败: ${response.statusCode}');
        await _logWarning(
          'RosemaryUpdater.checkUpdate',
          '检查更新失败',
          metadata: {'statusCode': response.statusCode},
        );
        throw Exception('Check update failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrintLog('检查更新异常: $e');
      await _logError(
        'RosemaryUpdater.checkUpdate',
        '检查更新异常',
        error: e,
        stackTrace: stackTrace,
      );
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
        error: '应用更新地址为空',
        success: false,
      ));
      await _logWarning(
        'RosemaryUpdater._runAppUpdate',
        '应用更新地址为空',
      );
      return;
    }

    try {
      await _logInfo(
        'RosemaryUpdater._runAppUpdate',
        '开始应用更新',
        metadata: {
          'installKind': updateInfo.appUpgradeInstallKind,
          'url': updateInfo.appUpgradeUrl,
        },
      );
      final installKind = updateInfo.appUpgradeInstallKind.toLowerCase();
      if (installKind == 'appstore' || installKind == 'testflight') {
        onStatusChanged(UpdateStatus(
          installing: true,
          message: '正在打开更新渠道...',
          progress: 100,
        ));
        await _launchExternalUpdateUrl(updateInfo, onStatusChanged);
        return;
      }

      onStatusChanged(UpdateStatus(
        downloading: true,
        message: '正在下载应用更新...',
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
      await _downloadResumable(
        updateInfo.appUpgradeUrl,
        filePath,
        onProgress: (received, total) {
          if (total > 0) {
            int progress = (received / total * 100).toInt();
            _maybeLogProgress(
              channel: 'RosemaryUpdater._runAppUpdate',
              progress: progress,
              lastProgress: _lastAppDownloadLogProgress,
              updater: (value) => _lastAppDownloadLogProgress = value,
              message: '应用更新下载进度',
              metadata: {
                'received': received,
                'total': total,
                'filePath': filePath,
              },
            );
            onStatusChanged(UpdateStatus(
              downloading: true,
              progress: progress,
              message: '正在下载应用更新...',
              receivedBytes: received,
              totalBytes: total,
            ));
          } else {
            onStatusChanged(UpdateStatus(
              downloading: true,
              progress: 0,
              message: '正在下载应用更新...',
              receivedBytes: received,
            ));
          }
        },
      );

      onStatusChanged(UpdateStatus(
        installing: true,
        message: '正在准备安装应用更新...',
        progress: 100,
      ));

      await _launchInstaller(
        filePath: filePath,
        updateInfo: updateInfo,
        onStatusChanged: onStatusChanged,
      );
    } catch (e, stackTrace) {
      onStatusChanged(UpdateStatus(
        error: _friendlyUpdateFailure(e),
        success: false,
      ));
      await _logError(
        'RosemaryUpdater._runAppUpdate',
        '应用更新失败',
        metadata: {'url': updateInfo.appUpgradeUrl},
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _runResUpdate(
    UpdateReceive updateInfo,
    void Function(UpdateStatus status) onStatusChanged,
  ) async {
    int resourceOverallProgress = 0;
    Directory? resourceBackup;
    Directory? resourceDirectory;
    void emitResourceStatus({
      required String message,
      required int progress,
      bool success = false,
      String? error,
      int receivedBytes = 0,
      int totalBytes = 0,
    }) {
      final normalized = progress.clamp(resourceOverallProgress, 100);
      resourceOverallProgress = normalized;
      onStatusChanged(UpdateStatus(
        installing: !success && error == null,
        downloading:
            !success && error == null && normalized < _resDownloadWeight,
        success: success,
        error: error,
        progress: normalized,
        message: message,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
      ));
    }

    onStatusChanged(UpdateStatus(
      downloading: true,
      progress: 0,
      message: '正在下载资源包...',
    ));
    await _logInfo(
      'RosemaryUpdater._runResUpdate',
      '开始资源更新',
      metadata: {
        'resUrl': updateInfo.resUpgradeUrl,
        'downloadDir': config.downloadDir,
      },
    );

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
      await _downloadResumable(
        updateInfo.resUpgradeUrl,
        zipPath,
        onProgress: (received, total) {
          if (total > 0) {
            final int stageProgress =
                (received / total * 100).toInt().clamp(0, 100);
            final int progress = _mapStageProgress(
              stageProgress: stageProgress,
              offset: 0,
              weight: _resDownloadWeight,
            );
            _maybeLogProgress(
              channel: 'RosemaryUpdater._runResUpdate',
              progress: stageProgress,
              lastProgress: _lastResDownloadLogProgress,
              updater: (value) => _lastResDownloadLogProgress = value,
              message: '资源包下载进度',
              metadata: {
                'received': received,
                'total': total,
                'zipPath': zipPath,
                'overallProgress': progress,
              },
            );
            emitResourceStatus(
              message: '正在下载资源包...',
              progress: progress,
              receivedBytes: received,
              totalBytes: total,
            );
          } else {
            emitResourceStatus(
              message: '正在下载资源包...',
              progress: resourceOverallProgress,
              receivedBytes: received,
            );
          }
        },
      );

      emitResourceStatus(
        message: '正在准备解压资源包...',
        progress: _resDownloadWeight,
      );

      // Unzip
      final scriptRunner = ScriptRunner(
          appVersion: config.appVersion,
          onMessage: (msg) {
            // Relay script messages?
            debugPrintLog('Script says: $msg');
            unawaited(_logInfo(
              'RosemaryUpdater.ScriptRunner',
              '资源脚本输出',
              metadata: {'message': msg},
            ));
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

      final bool unzipResult = await compute(
        _extractArchiveInBackground,
        <String>[zipPath, updateTempDir],
      );
      emitResourceStatus(
        message: '正在整理资源文件...',
        progress: _resDownloadWeight + _resPrimaryUnzipWeight,
      );

      if (!unzipResult) {
        throw Exception('解压资源更新包失败');
      }

      // Run script
      final _ResolvedResourceScript resolvedScript =
          await _resolveResourceScript(
        zipPath: zipPath,
        downloadPath: downloadPath,
        updateTempDir: updateTempDir,
        updateTempDirObj: updateTempDirObj,
        scriptRunner: scriptRunner,
        onLegacyUnzipProgress: (progress) {
          final int normalized = progress.clamp(0, 100);
          final int overallProgress = _mapStageProgress(
            stageProgress: normalized,
            offset: _resDownloadWeight + _resPrimaryUnzipWeight,
            weight: _resLegacyUnzipWeight,
          );
          emitResourceStatus(
            message: '正在整理资源文件...',
            progress: overallProgress,
          );
        },
      );

      if (resolvedScript.scriptPath.isEmpty) {
        throw Exception('未找到可执行的资源更新脚本');
      }
      emitResourceStatus(
        message: '正在准备执行资源更新脚本...',
        progress: _resDownloadWeight + _resUnzipWeight,
      );
      await _logInfo(
        'RosemaryUpdater._runResUpdate',
        '资源脚本已解析',
        metadata: {
          'scriptPath': resolvedScript.scriptPath,
          'initSetDir': resolvedScript.initSetDir,
        },
      );

      resourceDirectory = Directory(path.join(downloadPath, 'ZionRes'));
      resourceBackup = Directory(path.join(downloadPath, '.ZionRes.rollback'));
      if (await resourceBackup.exists()) {
        await resourceBackup.delete(recursive: true);
      }
      if (await resourceDirectory.exists()) {
        final copied = await compute(_copyDirectoryInBackground,
            <String>[resourceDirectory.path, resourceBackup.path]);
        if (!copied) throw Exception('无法创建资源回滚点，请检查可用存储空间');
      }

      bool scriptResult = await scriptRunner.fileScript(
          resolvedScript.scriptPath,
          initSetDir: resolvedScript.initSetDir,
          progressCallback: (total, sub) {
        final int stageProgress = _combineScriptProgress(total, sub);
        final int overallProgress = _mapStageProgress(
          stageProgress: stageProgress,
          offset: _resDownloadWeight + _resUnzipWeight,
          weight: _resScriptWeight,
        );
        _maybeLogProgress(
          channel: 'RosemaryUpdater._runResUpdate',
          progress: stageProgress,
          lastProgress: _lastResScriptLogProgress,
          updater: (value) => _lastResScriptLogProgress = value,
          message: '资源脚本执行进度',
          metadata: {
            'commandProgress': total,
            'subProgress': sub,
            'scriptPath': resolvedScript.scriptPath,
            'overallProgress': overallProgress,
          },
        );
        emitResourceStatus(
          message: '正在执行资源更新脚本...',
          progress: overallProgress,
        );
      });

      if (scriptResult) {
        if (await resourceBackup.exists()) {
          await resourceBackup.delete(recursive: true);
        }
        // Clean up
        if (await File(zipPath).exists()) {
          await File(zipPath).delete();
        }
        if (await updateTempDirObj.exists()) {
          await updateTempDirObj.delete(recursive: true);
        }
        await _logInfo(
          'RosemaryUpdater._runResUpdate',
          '资源更新完成',
          metadata: {
            'zipPath': zipPath,
            'scriptPath': resolvedScript.scriptPath,
          },
        );
        emitResourceStatus(
          message: '资源更新完成',
          progress: 100,
          success: true,
        );
      } else {
        throw Exception('资源更新脚本执行失败');
      }
    } catch (e, stackTrace) {
      if (resourceBackup != null && await resourceBackup.exists()) {
        if (resourceDirectory != null && await resourceDirectory.exists()) {
          await resourceDirectory.delete(recursive: true);
        }
        await resourceBackup.rename(resourceDirectory!.path);
      }
      emitResourceStatus(
        message: '更新失败',
        progress: resourceOverallProgress,
        error: _friendlyUpdateFailure(e),
      );
      await _logError(
        'RosemaryUpdater._runResUpdate',
        '资源更新失败',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Downloads into a durable partial file. Range-capable object storage can
  /// continue after network loss or process restart; servers that ignore Range
  /// safely restart the partial file instead of appending duplicate bytes.
  Future<void> _downloadResumable(
    String url,
    String destination, {
    required void Function(int received, int total) onProgress,
  }) async {
    final partial = File('$destination.part');
    var existing = await partial.exists() ? await partial.length() : 0;
    Response<ResponseBody> response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
        validateStatus: (status) => status == 200 || status == 206,
      ),
    );
    if (existing > 0 && response.statusCode != 206) {
      await partial.writeAsBytes(const []);
      existing = 0;
    }
    final contentLength = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        -1;
    final total = contentLength < 0 ? -1 : existing + contentLength;
    final sink = partial.openWrite(
      mode: existing > 0 ? FileMode.append : FileMode.write,
    );
    var received = existing;
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastUpdate) >= const Duration(milliseconds: 80) ||
            (total > 0 && received >= total)) {
          lastUpdate = now;
          onProgress(received, total);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      throw const HttpException('下载不完整，请重试');
    }
    final expectedHash = response.headers.value('x-amz-meta-sha256') ??
        response.headers.value('x-content-sha256');
    if (expectedHash != null && expectedHash.isNotEmpty) {
      final actual = (await sha256.bind(partial.openRead()).first).toString();
      if (actual.toLowerCase() != expectedHash.trim().toLowerCase()) {
        await partial.delete();
        throw const FormatException('下载文件完整性校验失败，请重新下载');
      }
    }
    final target = File(destination);
    if (await target.exists()) await target.delete();
    await partial.rename(destination);
    onProgress(received, total);
  }

  String _friendlyUpdateFailure(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code == 28 || code == 112) {
        return '存储空间不足，请清理空间后重试；原有资源未受影响';
      }
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || status == 410) {
        return '下载链接已过期，请重新检查更新';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return '网络连接中断，已保留下载进度，请稍后重试';
      }
    }
    return '更新失败：$error';
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
      await _logWarning(
        'RosemaryUpdater._launchInstaller',
        '打开安装包失败',
        metadata: {
          'filePath': filePath,
          'message': result.message,
        },
      );
      onStatusChanged(UpdateStatus(
        error: '打开安装包失败: ${result.message}',
        success: false,
      ));
      return;
    }

    onStatusChanged(UpdateStatus(
      success: true,
      message: _installSuccessMessage(updateInfo),
    ));
    await _logInfo(
      'RosemaryUpdater._launchInstaller',
      '安装程序已打开',
      metadata: {
        'filePath': filePath,
        'installKind': updateInfo.appUpgradeInstallKind,
      },
    );
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
        error: '更新地址为空',
        success: false,
      ));
      await _logWarning(
        'RosemaryUpdater._launchExternalUpdateUrl',
        '更新地址为空',
      );
      return;
    }

    final uri = Uri.tryParse(updateInfo.appUpgradeUrl);
    if (uri == null) {
      onStatusChanged(UpdateStatus(
        error: '更新地址无效',
        success: false,
      ));
      await _logWarning(
        'RosemaryUpdater._launchExternalUpdateUrl',
        '更新地址无效',
        metadata: {'url': updateInfo.appUpgradeUrl},
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      onStatusChanged(UpdateStatus(
        error: '打开更新地址失败',
        success: false,
      ));
      await _logWarning(
        'RosemaryUpdater._launchExternalUpdateUrl',
        '打开更新地址失败',
        metadata: {'url': updateInfo.appUpgradeUrl},
      );
      return;
    }

    onStatusChanged(UpdateStatus(
      success: true,
      message: _installSuccessMessage(updateInfo),
    ));
    await _logInfo(
      'RosemaryUpdater._launchExternalUpdateUrl',
      '已跳转到外部更新渠道',
      metadata: {'url': updateInfo.appUpgradeUrl},
    );
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
        return '已打开 DMG，请挂载后将应用拖入“应用程序”文件夹完成更新。';
      case 'exe':
      case 'msi':
        return '安装程序已打开，请按安装向导完成更新。';
      case 'appstore':
        final label = updateInfo.appUpgradeStoreLabel.isEmpty
            ? '应用商店'
            : updateInfo.appUpgradeStoreLabel;
        return '已跳转到$label，请继续完成更新。';
      case 'testflight':
        return '已跳转到 TestFlight，请继续完成更新。';
      default:
        return '应用更新安装已启动。';
    }
  }

  Future<_ResolvedResourceScript> _resolveResourceScript({
    required String zipPath,
    required String downloadPath,
    required String updateTempDir,
    required Directory updateTempDirObj,
    required ScriptRunner scriptRunner,
    void Function(int progress)? onLegacyUnzipProgress,
  }) async {
    final modernScriptPath = path.join(updateTempDir, 'update.rp');
    if (await File(modernScriptPath).exists()) {
      await _logInfo(
        'RosemaryUpdater._resolveResourceScript',
        '使用新版资源脚本',
        metadata: {'scriptPath': modernScriptPath},
      );
      return _ResolvedResourceScript(
        scriptPath: modernScriptPath,
        initSetDir: downloadPath,
      );
    }

    final legacyScriptPath = path.join(updateTempDir, 'res', 'install.rp');
    if (await File(legacyScriptPath).exists()) {
      await _logInfo(
        'RosemaryUpdater._resolveResourceScript',
        '检测到旧版资源脚本，准备按旧流程重新解压',
        metadata: {'scriptPath': legacyScriptPath},
      );
      final legacyResDir = Directory(path.join(downloadPath, 'res'));
      if (await legacyResDir.exists()) {
        await legacyResDir.delete(recursive: true);
      }
      final legacyScriptRunner = ScriptRunner(
        appVersion: config.appVersion,
        onMessage: scriptRunner.onMessage,
      );
      final bool unzipToLegacyPath = legacyScriptRunner.unzip(
        [zipPath, downloadPath],
        progressCallback: (progress) {
          onLegacyUnzipProgress?.call(progress);
        },
      );
      if (!unzipToLegacyPath) {
        throw Exception('无法将资源包解压到应用目录');
      }
      await _logInfo(
        'RosemaryUpdater._resolveResourceScript',
        '旧版资源包已重新解压到应用目录',
        metadata: {'targetDir': downloadPath},
      );
      return _ResolvedResourceScript(
        scriptPath: path.join(downloadPath, 'res', 'install.rp'),
        initSetDir: downloadPath,
      );
    }

    await _logWarning(
      'RosemaryUpdater._resolveResourceScript',
      '未找到资源更新脚本',
      metadata: {'updateTempDir': updateTempDir},
    );
    return const _ResolvedResourceScript(scriptPath: '', initSetDir: '');
  }

  void _maybeLogProgress({
    required String channel,
    required int progress,
    required int lastProgress,
    required void Function(int value) updater,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    final normalized = progress.clamp(0, 100);
    if (normalized == lastProgress) {
      return;
    }
    if (normalized != 0 &&
        normalized != 100 &&
        normalized ~/ 5 == lastProgress ~/ 5) {
      return;
    }
    updater(normalized);
    unawaited(_logInfo(
      channel,
      message,
      metadata: {
        'progress': normalized,
        ...?metadata,
      },
    ));
  }

  int _mapStageProgress({
    required int stageProgress,
    required int offset,
    required int weight,
  }) {
    final normalized = stageProgress.clamp(0, 100);
    final mapped = offset + ((normalized * weight) / 100).round();
    return mapped.clamp(0, 100);
  }

  int _combineScriptProgress(int total, int sub) {
    final normalizedTotal = total.clamp(0, 100);
    final normalizedSub = sub.clamp(0, 100);
    final combined = ((normalizedTotal * 100) + normalizedSub) / 100;
    return combined.round().clamp(0, 100);
  }

  Future<void> _logInfo(
    String source,
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    await config.logger?.call(
      UpdateLogLevel.info,
      source,
      message,
      metadata: metadata,
    );
  }

  Future<void> _logWarning(
    String source,
    String message, {
    Map<String, dynamic>? metadata,
  }) async {
    await config.logger?.call(
      UpdateLogLevel.warning,
      source,
      message,
      metadata: metadata,
    );
  }

  Future<void> _logError(
    String source,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    await config.logger?.call(
      UpdateLogLevel.error,
      source,
      message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
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

bool _extractArchiveInBackground(List<String> arguments) {
  if (arguments.length != 2) return false;
  final source = File(arguments[0]);
  if (!source.existsSync()) return false;
  try {
    final input = InputFileStream(source.path);
    final archive = ZipDecoder().decodeBuffer(input);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final output = path.normalize(path.join(arguments[1], entry.name));
      final root = path.normalize(arguments[1]);
      if (!path.isWithin(root, output)) continue;
      File(output)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entry.content as List<int>);
    }
    input.close();
    return true;
  } catch (_) {
    return false;
  }
}

bool _copyDirectoryInBackground(List<String> arguments) {
  if (arguments.length != 2) return false;
  final source = Directory(arguments[0]);
  if (!source.existsSync()) return true;
  try {
    for (final entity in source.listSync(recursive: true, followLinks: false)) {
      final relative = path.relative(entity.path, from: source.path);
      final destination = path.join(arguments[1], relative);
      if (entity is Directory) {
        Directory(destination).createSync(recursive: true);
      } else if (entity is File) {
        File(destination).createSync(recursive: true);
        entity.copySync(destination);
      }
    }
    return true;
  } catch (_) {
    return false;
  }
}

class _ResolvedResourceScript {
  final String scriptPath;
  final String initSetDir;

  const _ResolvedResourceScript({
    required this.scriptPath,
    required this.initSetDir,
  });
}
