import 'package:app/src/features/profile/data/models/user_dto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/features/auth/domain/entities/login_entity.dart';

part 'login_dto.freezed.dart';
part 'login_dto.g.dart';

@freezed
class LoginDto with _$LoginDto {
  const LoginDto._();
  const factory LoginDto({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    required UserDto user,
  }) = _LoginDto;

  factory LoginDto.fromJson(Map<String, dynamic> json) =>
      _$LoginDtoFromJson(json);

  LoginEntity toEntity() => LoginEntity(
    accessToken: accessToken,
    refreshToken: refreshToken,
    user: user.toEntity(),
  );
}
