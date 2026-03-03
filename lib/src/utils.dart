import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

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
  // Can be overridden or hooked
  print(str);
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
