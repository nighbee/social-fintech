import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/send_post_seal_result_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'send_post_seal_result_dto.freezed.dart';
part 'send_post_seal_result_dto.g.dart';

@freezed
class SendPostSealResultDto extends BaseDto with _$SendPostSealResultDto {
  const SendPostSealResultDto._();

  const factory SendPostSealResultDto({
    required String status,
    @JsonKey(name: 'ledger_entry_id') required String ledgerEntryId,
    @JsonKey(name: 'new_balance') required double newBalance,
  }) = _SendPostSealResultDto;

  factory SendPostSealResultDto.fromJson(Map<String, dynamic> json) =>
      _$SendPostSealResultDtoFromJson(json);

  SendPostSealResultEntity toEntity() => SendPostSealResultEntity(
        status: status,
        ledgerEntryId: ledgerEntryId,
        newBalance: newBalance,
      );
}
