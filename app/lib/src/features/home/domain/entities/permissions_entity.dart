import 'package:freezed_annotation/freezed_annotation.dart';

part 'permissions_entity.freezed.dart';
part 'permissions_entity.g.dart';

@freezed
class PermissionsEntity with _$PermissionsEntity {
  const factory PermissionsEntity({
    required bool canComment,
  }) = _PermissionsEntity;

  const factory PermissionsEntity.empty({
    @Default(false) bool canComment,
  }) = _PermissionsEntityEmpty;

  factory PermissionsEntity.fromJson(Map<String, dynamic> json) =>
      _$PermissionsEntityFromJson(json);
}
