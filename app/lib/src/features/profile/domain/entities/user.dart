import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/base/base_models/base_entity.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User extends BaseEntity with _$User {
  const User._();
  const factory User({
    required int id,
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
  }) = _User;
  String get fullName => '$firstName $lastName';

  const factory User.empty({
    @Default(0) int id,
    @Default("") String email,
    @Default("") String firstName,
    @Default("") String lastName,
    @Default("") String phone,
  }) = _UserEmpty;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
