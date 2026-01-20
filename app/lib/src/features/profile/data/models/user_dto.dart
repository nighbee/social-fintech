import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/base/base_models/base_dto.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
class UserDto extends BaseDto with _$UserDto {
  const UserDto._();
  const factory UserDto({
    required int id,
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  User toEntity() => User(
    id: id,
    email: email,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
  );
}
