import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/permissions_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'permissions_dto.freezed.dart';
part 'permissions_dto.g.dart';

@freezed
class PermissionsDto extends BaseDto with _$PermissionsDto {
  const PermissionsDto._();
  const factory PermissionsDto({
    @JsonKey(name: 'can_comment') required bool canComment,
  }) = _PermissionsDto;

  factory PermissionsDto.fromJson(Map<String, dynamic> json) =>
      _$PermissionsDtoFromJson(json);

  PermissionsEntity toEntity() => PermissionsEntity(
        canComment: canComment,
      );
}
