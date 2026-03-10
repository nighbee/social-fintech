import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'author_info_dto.freezed.dart';
part 'author_info_dto.g.dart';

@freezed
class AuthorInfoDto extends BaseDto with _$AuthorInfoDto {
  const AuthorInfoDto._();
  const factory AuthorInfoDto({
    required String id,
    required String username,
    @JsonKey(name: 'full_name') required String fullName,
    @JsonKey(name: 'profile_pic_url') required String profilePicUrl,
    required String rank,
    @JsonKey(name: 'rank_sub_level') String? rankSubLevel,
  }) = _AuthorInfoDto;

  factory AuthorInfoDto.fromJson(Map<String, dynamic> json) =>
      _$AuthorInfoDtoFromJson(json);

  AuthorInfoEntity toEntity() => AuthorInfoEntity(
      id: id,
      username: username,
      fullName: fullName,
      profilePicUrl: profilePicUrl,
      rank: rank,
      rankSubLevel: rankSubLevel ?? '',
    );
}
