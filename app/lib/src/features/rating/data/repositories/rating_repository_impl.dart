import 'package:app/src/features/rating/data/sources/remote/i_rating_remote.dart';
import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:injectable/injectable.dart';

abstract class IRatingRepository {
  Future<Either<DomainException, List<Map<String, dynamic>>>>
      fetchGlobalLeaderboard({String scope, int limit, String? cursor});
}

@named
@LazySingleton(as: IRatingRepository)
class RatingRepositoryImpl implements IRatingRepository {
  RatingRepositoryImpl(this._remote);

  final IRatingRemote _remote;

  @override
  Future<Either<DomainException, List<Map<String, dynamic>>>>
      fetchGlobalLeaderboard({
    String scope = 'district',
    int limit = 50,
    String? cursor,
  }) async {
    try {
      return await _remote.getGlobalLeaderboard(
        scope: scope,
        limit: limit,
        cursor: cursor,
      );
    } catch (e) {
      return Left(UnknownException(message: e.toString()));
    }
  }
}
