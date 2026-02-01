import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_profile_request.freezed.dart';
part 'update_profile_request.g.dart';

@freezed
class UpdateProfileRequest with _$UpdateProfileRequest {
  const factory UpdateProfileRequest({
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    String? bio,
    @JsonKey(name: 'location_city') String? locationCity,
    @JsonKey(name: 'location_country') String? locationCountry,
    @JsonKey(name: 'is_location_public') bool? isLocationPublic,
    @JsonKey(name: 'is_profile_public') bool? isProfilePublic,
  }) = _UpdateProfileRequest;

  factory UpdateProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateProfileRequestFromJson(json);
}
