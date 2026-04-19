import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'claim_daily_accrual_request.freezed.dart';
part 'claim_daily_accrual_request.g.dart';

@freezed
class ClaimDailyAccrualRequest extends BaseRequest
    with _$ClaimDailyAccrualRequest {
  const ClaimDailyAccrualRequest._();

  const factory ClaimDailyAccrualRequest({
    @JsonKey(name: 'idempotency_key') @Default('') String idempotencyKey,
  }) = _ClaimDailyAccrualRequest;

  factory ClaimDailyAccrualRequest.fromJson(Map<String, dynamic> json) =>
      _$ClaimDailyAccrualRequestFromJson(json);

  Map<String, dynamic> toPayload() {
    final payload = toJson();
    final trimmedIdempotencyKey = idempotencyKey.trim();
    if (trimmedIdempotencyKey.isEmpty) {
      payload.remove('idempotency_key');
    } else {
      payload['idempotency_key'] = trimmedIdempotencyKey;
    }
    return payload;
  }
}
