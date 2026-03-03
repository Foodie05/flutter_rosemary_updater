// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_receive.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateReceive _$UpdateReceiveFromJson(Map<String, dynamic> json) =>
    UpdateReceive(
      appUpgrade: json['appUpgrade'] as bool,
      appUpgradeDescription: json['appUpgradeDescription'] as String,
      appUpgradeUrl: json['appUpgradeUrl'] as String,
      isPatch: json['isPatch'] as bool,
      resUpgrade: json['resUpgrade'] as bool,
      resUpgradeDescription: json['resUpgradeDescription'] as String,
      resUpgradeUrl: json['resUpgradeUrl'] as String,
    );

Map<String, dynamic> _$UpdateReceiveToJson(UpdateReceive instance) =>
    <String, dynamic>{
      'appUpgrade': instance.appUpgrade,
      'appUpgradeDescription': instance.appUpgradeDescription,
      'appUpgradeUrl': instance.appUpgradeUrl,
      'isPatch': instance.isPatch,
      'resUpgrade': instance.resUpgrade,
      'resUpgradeDescription': instance.resUpgradeDescription,
      'resUpgradeUrl': instance.resUpgradeUrl,
    };
