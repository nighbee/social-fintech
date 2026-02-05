import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:app/src/core/base/base_models/base_entity.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User extends BaseEntity with _$User {
  const factory User({
    required String id,
    String? email,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
  }) = _User;

  const factory User.empty({
    @Default('') String id,
    @Default(null) String? email,
    @Default(null) String? username,
    @Default(null) String? avatarUrl,
    @Default(null) DateTime? createdAt,
  }) = _UserEmpty;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
