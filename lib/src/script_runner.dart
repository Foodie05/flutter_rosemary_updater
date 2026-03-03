// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'utils.dart';

class GetArgResult {
  late bool result;
  late String value;
  late String valueType;
  GetArgResult({required this.result, required this.value, required this.valueType});
}

class ValueMap {
  late String valueName;
  late String valueType;
  late String value;
  ValueMap({required this.valueName, required this.valueType, required this.value});
}

class ScriptRunner {
  String setDir = '';
  bool endSignal = false; // call when successfully exited
  final void Function(String message)? onMessage;
  
  List<ValueMap> valueMap = [
    ValueMap(valueName: 'empty', valueType: 'String', value: ''),
  ];

  ScriptRunner({this.onMessage, int? appVersion}) {
    if (appVersion != null) {
      valueMap.add(ValueMap(valueName: 'appVersion', valueType: 'int', value: appVersion.toString()));
    }
  }

  Future<bool> shellScript(List<String> args,
      {String initSetDir = '',
      required void Function(int totalProgress, int subProgress) progressCallback}) async {
    setDir = initSetDir;
    endSignal = false;
    for (int i = 0; i < args.length; i++) {
      progressCallback((i / args.length * 100).toInt(), 0);
      List<String> commandWithArg = commandSeparator(args[i]);
      bool commandResult = await commandRealize(commandWithArg, (int progress) {
        progressCallback((i / args.length * 100).toInt(), progress);
      });
      if (commandResult == false) {
        if (endSignal == true) {
          debugPrintLog('Script ended with no error.');
          return true;
        }
        debugPrintLog('Error occurred, script interrupted');
        return false;
      }
      progressCallback((i / args.length * 100).toInt(), 100);
    }
    debugPrintLog('Script ended with no error.');
    return true;
  }

  Future<bool> fileScript(String filePath,
      {String initSetDir = '',
      required void Function(int totalProgress, int subProgress) progressCallback}) async {
    setDir = initSetDir;
    endSignal = false;
    if (!await File(filePath).exists()) {
      debugPrintLog('In method fileScript: No such script file existed');
      return false;
    }
    List<String> command = File(filePath).readAsLinesSync();
    for (int i = 0; i < command.length; i++) {
      progressCallback((i / command.length * 100).toInt(), 0);
      List<String> commandWithArg = commandSeparator(command[i]);
      bool commandResult = await commandRealize(commandWithArg, (int progress) {
        progressCallback((i / command.length * 100).toInt(), progress);
      });
      if (commandResult == false) {
        if (endSignal == true) {
          debugPrintLog('Script ended with no error.');
          return true;
        }
        debugPrintLog('Error occurred, script interrupted');
        return false;
      }
      progressCallback((i / command.length * 100).toInt(), 100);
    }
    debugPrintLog('Script ended with no error.');
    return true;
  }

  List<String> commandSeparator(String? command) {
    if (command == null) {
      return [];
    }
    List<String> result = [];
    while (command!.isNotEmpty) {
      int index = command.indexOf(' '); //check for space
      if (index == -1) {
        //no space existed
        return result + [command];
      }
      result.add(command.substring(0, index));
      command = command.substring(index + 1);
    }
    return result;
  }

  Future<bool> commandRealize(
      List<String> commandWithArg, void Function(int progress) progressCallback) async {
    if (commandWithArg.isEmpty) {
      return true;
    }
    String cmd = commandWithArg[0];
    List<String> args = commandWithArg.sublist(1);

    if (cmd == 'say') {
      return say(args);
    } else if (cmd == 'save_arg') {
      return save_arg(args);
    } else if (cmd == 'is_arg_equal') {
      return is_arg_equal(args);
    } else if (cmd == 'compare_num') {
      return compare_num(args);
    } else if (cmd == 'if') {
      return await if_func(args);
    } else if (cmd == 'end') {
      endSignal = true;
      return false;
    } else if (cmd == 'set_dir') {
      return await set_dir(args);
    } else if (cmd == 'dl') {
      return await dl(args, progressCallback: progressCallback);
    } else if (cmd == 'rm') {
      return await rm(args);
    } else if (cmd == 'rm_dir') {
      return await rm_dir(args);
    } else if (cmd == 'mv') {
      return await mv(args);
    } else if (cmd == 'mv_dir') {
      return await mv_dir(args);
    } else if (cmd == 'cp') {
      return await cp(args);
    } else if (cmd == 'cp_dir') {
      return await cp_dir(args);
    } else if (cmd == 'mkdir') {
      return await mkdir(args);
    } else if (cmd == 'touch') {
      return await touch(args);
    } else if (cmd == 'chk_file') {
      return await chk_file(args);
    } else if (cmd == 'chk_dir') {
      return await chk_dir(args);
    } else if (cmd == 'unzip') {
      return unzip(args, progressCallback: progressCallback);
    } else if (cmd == 'clear') {
      return await clear(args);
    } else if (cmd.startsWith('//')) {
      return true;
    } else {
      debugPrintLog('In method commandRealize: No such method \'$cmd\' is defined');
      return false;
    }
  }

  bool say(List<String> sayArgs) {
    String msg = '';
    for (int i = 0; i < sayArgs.length; i++) {
      if (i != 0) {
        msg += ' ';
      }
      GetArgResult getArgResult = get_arg(sayArgs[i]);
      if (getArgResult.result == false) {
        debugPrintLog('In method say: error occurred when calling get_arg by passing value: ${sayArgs[i]}');
        return false;
      }
      msg += getArgResult.value;
    }
    if (onMessage != null) {
      onMessage!(msg);
    }
    debugPrintLog(msg);
    return true;
  }

  bool save_arg(List<String> args){
    if(args.length<3){
      debugPrintLog('\nIn method save_arg: args are not enough: supposed 3, given ${args.length}');
      return false;
    }
    List<String> argType=['String','bool','int','double'];
    if(!argType.contains(args[0])){
      debugPrintLog('\nIn method save_arg: value type ${args[0]} is not pre-defined in valueType');
      return false;
    }
    if(valueMap.indexWhere((value)=>value.valueName==args[1])>=0){
      return false; 
    }
    
     if(args[0]=='int'){
      if(int.tryParse(args[2])==null){
        debugPrintLog('\nIn method save_arg: value ${args[2]} is not an int type value');
        return false;
      }
    }else if(args[0]=='double'){
      if(double.tryParse(args[2])==null){
        debugPrintLog('\nIn method save_arg: value ${args[2]} is not a double type value');
        return false;
      }
    }else if(args[0]=='bool'){
      if(bool.tryParse(args[2])==null){
        debugPrintLog('\nIn method save_arg: value ${args[2]} is not a bool type value');
        return false;
      }
    }

    String valueArg='';
    for(int i=2;i<args.length;i++){
      valueArg+=args[i];
      if(i+1!=args.length) valueArg+=' ';
    }
    valueMap.add(ValueMap(valueName: args[1], valueType: args[0], value: valueArg));
    return true;
  }

  GetArgResult get_arg(String valueNameOrigin){
    if(valueNameOrigin.isEmpty) return GetArgResult(result: false, value: '', valueType: 'String');
    if(valueNameOrigin[0]!='\\'){
      String valueType='String';
      if(bool.tryParse(valueNameOrigin)!=null){
        valueType='bool';
      }
      if(int.tryParse(valueNameOrigin)!=null){
        valueType='int';
      }
      if(double.tryParse(valueNameOrigin)!=null){
        valueType='double';
      }
      return GetArgResult(result: true, value: valueNameOrigin,valueType: valueType);
    }
    String valueName=valueNameOrigin.substring(1);
    int index=valueMap.indexWhere((value)=>value.valueName==valueName);
    try{
      if (index == -1) throw Exception('Value not found');
      String value=valueMap[index].value;
      return GetArgResult(result: true, value: value, valueType: valueMap[index].valueType);
    }catch(e){
      debugPrintLog('In method get_arg: value ${valueNameOrigin.substring(1)} does not exist in valueMap');
      return GetArgResult(result: false, value: '', valueType: 'String');
    }
  }

  Future<bool> set_dir(List<String> dirs) async {
    if(dirs.isEmpty){
      debugPrintLog('In method set_dir: You should at least give one arg to save dir');
      return false;
    }
    String dir=dirs[0];
    GetArgResult getArgResult=get_arg(dir);
    if(getArgResult.result==false){
      debugPrintLog('In method set_dir: Error occurred when calling get_arg by passing: $dir');
    }
    Directory directory=Directory(getArgResult.value);
    try{
      if(!await directory.exists()&&getArgResult.value!=''){
        debugPrintLog('In method set_dir: Given dir path \'$dir\' does not exist.');
        return false;
      }
    }catch(e){
      debugPrintLog('In method set_dir: caught an error at $e');
      return false;
    }
    setDir=getArgResult.value;
    debugPrintLog('In method set_dir: setDir is set to \'$setDir\'');
    return true;
  }

  Future<bool> dl(List<String> args, {required void Function(int progress) progressCallback}) async {
      if(args.length<2) return false;
      GetArgResult r1 = get_arg(args[0]);
      GetArgResult r2 = get_arg(args[1]);
      if(!r1.result || !r2.result) return false;
      String url = r1.value;
      String savePath = r2.value;
      if(setDir!='') savePath = path.join(setDir, savePath);
      
      Dio dio = Dio();
      int downloadProgress=0;
      int maxRetries=3;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await dio.download(
            url,
            savePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                downloadProgress = (received / total * 100).toInt();
                progressCallback(downloadProgress);
              }
            },
          );
          return true;
        } catch (e) {
          if (attempt == maxRetries) {
            progressCallback(-1);
            return false;
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      return false;
  }

  bool is_arg_equal(List<String> args) {
    if (args.length < 3) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    if (r1.value == r2.value) {
      return save_arg(['bool', args[2], 'true']);
    } else {
      return save_arg(['bool', args[2], 'false']);
    }
  }

  bool compare_num(List<String> args) {
    if (args.length < 3) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    try {
      double n1 = double.parse(r1.value);
      double n2 = double.parse(r2.value);
      if (n1 > n2) return save_arg(['String', args[2], 'greater']);
      if (n1 == n2) return save_arg(['String', args[2], 'equal']);
      return save_arg(['String', args[2], 'smaller']);
    } catch (e) {
      return false;
    }
  }

  Future<bool> if_func(List<String> args) async {
    GetArgResult r = get_arg(args[0]);
    if (!r.result || r.valueType != 'bool') return false;
    if (r.value == 'false') {
      return true;
    } else {
      return await commandRealize(args.sublist(1), (int progress) {});
    }
  }

  Future<bool> rm(List<String> args) async {
    if (args.isEmpty) return false;
    GetArgResult r = get_arg(args[0]);
    if (!r.result) return false;
    String p = setDir == '' ? r.value : path.join(setDir, r.value);
    File f = File(p);
    if (await f.exists()) {
      try {
        await f.delete();
        return true;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<bool> rm_dir(List<String> args) async {
    if (args.isEmpty) return false;
    GetArgResult r = get_arg(args[0]);
    if (!r.result) return false;
    String p = setDir == '' ? r.value : path.join(setDir, r.value);
    Directory d = Directory(p);
    if (await d.exists()) {
      try {
        await d.delete(recursive: true);
        return true;
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  Future<bool> mv(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p1 = setDir == '' ? r1.value : path.join(setDir, r1.value);
    String p2 = setDir == '' ? r2.value : path.join(setDir, r2.value);
    try {
      await File(p1).rename(p2);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> mv_dir(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p1 = setDir == '' ? r1.value : path.join(setDir, r1.value);
    String p2 = setDir == '' ? r2.value : path.join(setDir, r2.value);
    try {
      Directory d1 = Directory(p1);
      if (!await d1.exists()) return false;
      Directory d2 = Directory(p2);
      if (await d2.exists()) await d2.delete(recursive: true);
      await d1.rename(p2);
      return true;
    } catch (e) {
      // Fallback copy delete
       try {
        final sourceDir = Directory(p1);
        final targetDir = Directory(p2);
        await targetDir.create(recursive: true);
        await _copyDirectoryContents(sourceDir, targetDir);
        await sourceDir.delete(recursive: true);
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  Future<bool> cp(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p1 = setDir == '' ? r1.value : path.join(setDir, r1.value);
    String p2 = setDir == '' ? r2.value : path.join(setDir, r2.value);
    try {
      await File(p1).copy(p2);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cp_dir(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p1 = setDir == '' ? r1.value : path.join(setDir, r1.value);
    String p2 = setDir == '' ? r2.value : path.join(setDir, r2.value);
    try {
      Directory d1 = Directory(p1);
      Directory d2 = Directory(p2);
      if (await d1.exists()) {
        if (!await d2.exists()) await d2.create(recursive: true);
        return await _copyDirectoryContents(d1, d2);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _copyDirectoryContents(Directory source, Directory target) async {
    try {
      await for (var entity in source.list(recursive: false)) {
        final targetEntity = target.uri.resolve(entity.uri.pathSegments.last);
        if (entity is File) {
          await entity.copy(targetEntity.path);
        } else if (entity is Directory) {
          final newTarget = Directory(targetEntity.path);
          if (!await newTarget.exists()) await newTarget.create();
          if (!await _copyDirectoryContents(entity, newTarget)) return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> mkdir(List<String> args) async {
    if (args.isEmpty) return false;
    GetArgResult r = get_arg(args[0]);
    if (!r.result) return false;
    String p = setDir == '' ? r.value : path.join(setDir, r.value);
    try {
      await Directory(p).create(recursive: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> touch(List<String> args) async {
    if (args.isEmpty) return false;
    GetArgResult r = get_arg(args[0]);
    if (!r.result) return false;
    String p = setDir == '' ? r.value : path.join(setDir, r.value);
    File f = File(p);
    try {
      if (args.length == 1) {
        if (!await f.exists()) await f.create();
      } else {
        if (await f.exists()) return false;
        await f.create();
        var sink = f.openWrite();
        for (int i = 1; i < args.length; i++) {
          GetArgResult val = get_arg(args[i]);
          if (!val.result) return false;
          sink.writeln(val.value);
        }
        await sink.flush();
        await sink.close();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> chk_file(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p = setDir == '' ? r1.value : path.join(setDir, r1.value);
    bool exists = await File(p).exists();
    return save_arg(['bool', r2.value, exists.toString()]);
  }

  Future<bool> chk_dir(List<String> args) async {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String p = setDir == '' ? r1.value : path.join(setDir, r1.value);
    bool exists = await Directory(p).exists();
    return save_arg(['bool', r2.value, exists.toString()]);
  }

  bool unzip(List<String> args, {required void Function(int progress) progressCallback}) {
    if (args.length < 2) return false;
    GetArgResult r1 = get_arg(args[0]);
    GetArgResult r2 = get_arg(args[1]);
    if (!r1.result || !r2.result) return false;
    String zipPath = r1.value;
    String unzipToPath = r2.value;
    if (setDir != '') {
      zipPath = path.join(setDir, zipPath);
      unzipToPath = path.join(setDir, unzipToPath);
    }

    if (!File(zipPath).existsSync()) return false;

    try {
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      int totalFiles = archive.files.length;
      int extractedFiles = 0;

      for (final file in archive.files) {
        if (file.isFile) {
          final outputPath = path.join(unzipToPath, file.name);
          final outputDir = Directory(path.dirname(outputPath));
          if (!outputDir.existsSync()) outputDir.createSync(recursive: true);
          File(outputPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
          extractedFiles++;
          progressCallback(((extractedFiles / totalFiles) * 100).toInt());
        }
      }
      inputStream.close();
      return true;
    } catch (e) {
      progressCallback(-1);
      return false;
    }
  }

  Future<bool> clear(List<String> args) async {
    if (args.isEmpty) return false;
    GetArgResult r = get_arg(args[0]);
    if (!r.result) return false;
    String p = setDir == '' ? r.value : path.join(setDir, r.value);
    
    if (!await Directory(p).exists()) return false;
    
    try {
      final dir = Directory(p);
      await for (var entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
