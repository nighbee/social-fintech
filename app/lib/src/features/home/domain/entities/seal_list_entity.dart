import 'package:app/src/features/home/domain/entities/seal_response_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'seal_list_entity.freezed.dart';
part 'seal_list_entity.g.dart';

@freezed
class SealListEntity with _$SealListEntity {
  const factory SealListEntity({
    required List<SealResponseEntity> items,
    @Default('') String nextCursor,
  }) = _SealListEntity;

  const factory SealListEntity.empty({
    @Default(<SealResponseEntity>[]) List<SealResponseEntity> items,
    @Default('') String nextCursor,
  }) = _SealListEntityEmpty;

  factory SealListEntity.fromJson(Map<String, dynamic> json) =>
      _$SealListEntityFromJson(json);
}
