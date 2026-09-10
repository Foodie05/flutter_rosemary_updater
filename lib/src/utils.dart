import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

enum UpdateLogLevel {
  info,
  warning,
  error,
}

typedef UpdateLogCallback = Future<void> Function(
  UpdateLogLevel level,
  String source,
  String message, {
  Map<String, dynamic>? metadata,
  Object? error,
  StackTrace? stackTrace,
});

enum UpdaterPlatformType {
  android,
  iOS,
  web,
  windows,
  linux,
  macOS,
  unknown,
}

void debugPrintLog(String str) {
  stdout.writeln(str);
}

String generateMd5(String input) {
  var bytes = utf8.encode(input);
  var digest = md5.convert(bytes);
  return digest.toString();
}

Future<String> readFileAsString(String filePath) async {
  File file = File(filePath);
  try {
    String content = await file.readAsString();
    return content;
  } catch (e) {
    return '';
  }
}

Future<int> readIntFromFile(String filePath) async {
  File file = File(filePath);
  try {
    String content = await file.readAsString();
    return int.parse(content);
  } catch (e) {
    return 0; // Default or error
  }
}
