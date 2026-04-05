import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_profiles_request.freezed.dart';
part 'search_profiles_request.g.dart';

@freezed
class SearchProfilesRequest extends BaseRequest with _$SearchProfilesRequest {
  const SearchProfilesRequest._();

  const factory SearchProfilesRequest({
    required String query,
    @Default(20) int limit,
    @Default(0) int offset,
  }) = _SearchProfilesRequest;

  factory SearchProfilesRequest.fromJson(Map<String, dynamic> json) =>
      _$SearchProfilesRequestFromJson(json);

  String get normalizedQuery {
    final trimmedQuery = query.trim();
    return trimmedQuery.replaceFirst(RegExp(r'^@+'), '');
  }

  Map<String, dynamic> toQuery() {
    final sanitizedQuery = normalizedQuery;
    return <String, dynamic>{
      'query': sanitizedQuery,
      'limit': limit,
      'offset': offset,
    };
  }
}
