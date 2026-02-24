import 'package:freezed_annotation/freezed_annotation.dart';

part 'phone_code_request.freezed.dart';

@freezed
class PhoneCodeRequest with _$PhoneCodeRequest {
  const factory PhoneCodeRequest({
    required String countryCode,
    required String phoneNumber,
    required String purpose,
  }) = _PhoneCodeRequest;
}
