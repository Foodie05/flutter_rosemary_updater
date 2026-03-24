import 'package:json_annotation/json_annotation.dart';
part 'update_receive.g.dart';

///Request
@JsonSerializable()
class UpdateReceive {
  @JsonKey(name: "appUpgrade")
  bool appUpgrade;
  @JsonKey(name: "appUpgradeDescription")
  String appUpgradeDescription;
  @JsonKey(name: "appUpgradeUrl")
  String appUpgradeUrl;
  @JsonKey(name: "appUpgradePlatform")
  String appUpgradePlatform;
  @JsonKey(name: "appUpgradeInstallKind")
  String appUpgradeInstallKind;
  @JsonKey(name: "appUpgradeStoreLabel")
  String appUpgradeStoreLabel;
  @JsonKey(name: "appUpgradeNotes")
  String appUpgradeNotes;
  @JsonKey(name: "isPatch")
  bool isPatch;
  @JsonKey(name: "resUpgrade")
  bool resUpgrade;
  @JsonKey(name: "resUpgradeDescription")
  String resUpgradeDescription;
  @JsonKey(name: "resUpgradeUrl")
  String resUpgradeUrl;

  UpdateReceive({
    required this.appUpgrade,
    required this.appUpgradeDescription,
    required this.appUpgradeUrl,
    required this.appUpgradePlatform,
    required this.appUpgradeInstallKind,
    required this.appUpgradeStoreLabel,
    required this.appUpgradeNotes,
    required this.isPatch,
    required this.resUpgrade,
    required this.resUpgradeDescription,
    required this.resUpgradeUrl,
  });

  factory UpdateReceive.fromJson(Map<String, dynamic> json) =>
      _$UpdateReceiveFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateReceiveToJson(this);
}
