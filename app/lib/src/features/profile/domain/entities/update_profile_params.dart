import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_profile_params.freezed.dart';

@freezed
class UpdateProfileParams with _$UpdateProfileParams {
  const factory UpdateProfileParams({
    String? displayName,
    String? firstName,
    String? lastName,
    String? bio,
    String? locationCity,
    String? locationCountry,
    bool? isLocationPublic,
    bool? isProfilePublic,
  }) = _UpdateProfileParams;
}
