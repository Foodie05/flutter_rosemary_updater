// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateRequest _$UpdateRequestFromJson(Map<String, dynamic> json) =>
    UpdateRequest(
      appName: json['appName'] as String,
      appPasswd: json['appPasswd'] as String,
      appVersion: (json['appVersion'] as num).toInt(),
      betaPasswd: json['betaPasswd'] as String,
      resVersion: (json['resVersion'] as num).toInt(),
    );

Map<String, dynamic> _$UpdateRequestToJson(UpdateRequest instance) =>
    <String, dynamic>{
      'appName': instance.appName,
      'appPasswd': instance.appPasswd,
      'appVersion': instance.appVersion,
      'betaPasswd': instance.betaPasswd,
      'resVersion': instance.resVersion,
    };
