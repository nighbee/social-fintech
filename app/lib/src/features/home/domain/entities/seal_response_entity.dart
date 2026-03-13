import 'package:app/src/features/home/domain/entities/author_info_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seal_response_entity.freezed.dart';
part 'seal_response_entity.g.dart';

@freezed
class SealResponseEntity with _$SealResponseEntity {
  const factory SealResponseEntity({
    required AuthorInfoEntity user,
    required int amount,
    @Default('') String comment,
    required String createdAt,
  }) = _SealResponseEntity;

  const factory SealResponseEntity.empty({
    @Default(AuthorInfoEntity.empty()) AuthorInfoEntity user,
    @Default(0) int amount,
    @Default('') String comment,
    @Default('') String createdAt,
  }) = _SealResponseEntityEmpty;

  factory SealResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$SealResponseEntityFromJson(json);
}
