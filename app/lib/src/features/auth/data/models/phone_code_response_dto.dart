import 'package:freezed_annotation/freezed_annotation.dart';

part 'phone_code_response_dto.freezed.dart';
part 'phone_code_response_dto.g.dart';

@freezed
class PhoneCodeResponseDto with _$PhoneCodeResponseDto {
  const PhoneCodeResponseDto._();
  const factory PhoneCodeResponseDto({
    @JsonKey(name: 'verification_id') required String verificationId,
    @JsonKey(name: 'expires_at') String? expiresAt,
  }) = _PhoneCodeResponseDto;

  factory PhoneCodeResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PhoneCodeResponseDtoFromJson(json);
}
