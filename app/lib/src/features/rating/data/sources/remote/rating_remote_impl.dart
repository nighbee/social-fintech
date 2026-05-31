import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/rating/data/sources/remote/i_rating_remote.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IRatingRemote)
class RatingRemoteImpl implements IRatingRemote {
  RatingRemoteImpl(@Named('DioClient') this._restClient);

  final RestClient _restClient;

  @override
  Future<Either<DomainException, List<Map<String, dynamic>>>>
      getGlobalLeaderboard({
    String scope = 'district',
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final query = <String, dynamic>{
        'scope': scope,
        'limit': limit,
      };
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }

      final response = await _restClient.get(
        EndPoints.leaderboard,
        queryParameters: query,
      );

      return response.fold((error) => Left(error), (result) {
        final raw = result.data;
        if (raw is! Map) {
          return Left(
              UnknownException(message: 'Invalid leaderboard response'));
        }

        final entries = raw['entries'];
        if (entries is! List) {
          return Left(UnknownException(message: 'Invalid leaderboard entries'));
        }

        final items = entries
            .whereType<Map>()
            .map((item) => _normalizeEntry(Map<String, dynamic>.from(item)))
            .toList();

        return Right(items);
      });
    } catch (e) {
      return Left(
        e is DomainException ? e : UnknownException(message: e.toString()),
      );
    }
  }

  Map<String, dynamic> _normalizeEntry(Map<String, dynamic> item) {
    final displayName = item['display_name']?.toString();
    final username = item['username']?.toString();

    return <String, dynamic>{
      ...item,
      'name': (displayName?.isNotEmpty ?? false)
          ? displayName
          : ((username?.isNotEmpty ?? false) ? username : 'Unknown'),
      'honor':
          item['weekly_score'] ?? item['honor'] ?? item['honor_score'] ?? 0,
      'rank_tier': item['rank_quality'] ??
          item['quality_name'] ??
          item['rank_tier'] ??
          '',
      'rank_grade': item['rank_level'] ?? item['rank_grade'] ?? '',
    };
  }
}
