import 'package:freezed_annotation/freezed_annotation.dart';

part 'author_info_entity.freezed.dart';
part 'author_info_entity.g.dart';

@freezed
class AuthorInfoEntity with _$AuthorInfoEntity {
  const factory AuthorInfoEntity({
    required String id,
    required String username,
    required String fullName,
    required String profilePicUrl,
    required String rank,
    @Default('') String rankSubLevel,
  }) = _AuthorInfoEntity;

  const factory AuthorInfoEntity.empty({
    @Default('') String id,
    @Default('') String username,
    @Default('') String fullName,
    @Default('') String profilePicUrl,
    @Default('') String rank,
    @Default('') String rankSubLevel,
  }) = _AuthorInfoEntityEmpty;

  factory AuthorInfoEntity.fromJson(Map<String, dynamic> json) =>
      _$AuthorInfoEntityFromJson(json);
}
