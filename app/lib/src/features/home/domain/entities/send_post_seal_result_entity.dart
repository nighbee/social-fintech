import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_post_seal_result_entity.freezed.dart';
part 'send_post_seal_result_entity.g.dart';

@freezed
class SendPostSealResultEntity with _$SendPostSealResultEntity {
  const factory SendPostSealResultEntity({
    required String status,
    @Default('') String ledgerEntryId,
    @Default(0) double newBalance,
  }) = _SendPostSealResultEntity;

  const factory SendPostSealResultEntity.empty({
    @Default('') String status,
    @Default('') String ledgerEntryId,
    @Default(0) double newBalance,
  }) = _SendPostSealResultEntityEmpty;

  factory SendPostSealResultEntity.fromJson(Map<String, dynamic> json) =>
      _$SendPostSealResultEntityFromJson(json);
}
