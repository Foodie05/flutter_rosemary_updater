import 'package:json_annotation/json_annotation.dart';
part 'update_request.g.dart';

///Request
@JsonSerializable()
class UpdateRequest {
  @JsonKey(name: "appName")
  String appName;
  @JsonKey(name: "appPasswd")
  String appPasswd;
  @JsonKey(name: "appVersion")
  int appVersion;
  @JsonKey(name: "betaPasswd")
  String betaPasswd;
  @JsonKey(name: "resVersion")
  int resVersion;

  UpdateRequest({
    required this.appName,
    required this.appPasswd,
    required this.appVersion,
    required this.betaPasswd,
    required this.resVersion,
  });

  factory UpdateRequest.fromJson(Map<String, dynamic> json) => _$UpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateRequestToJson(this);
}
