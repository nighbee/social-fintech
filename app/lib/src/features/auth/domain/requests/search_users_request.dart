import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_users_request.freezed.dart';

@freezed
class SearchUsersRequest with _$SearchUsersRequest {
  const factory SearchUsersRequest({
    required String firstName,
    required String lastName,
    @Default(20) int limit,
  }) = _SearchUsersRequest;
}
