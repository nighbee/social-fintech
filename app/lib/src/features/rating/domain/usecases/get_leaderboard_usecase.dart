import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:injectable/injectable.dart';
import 'package:app/src/features/rating/data/repositories/rating_repository_impl.dart';

@lazySingleton
class GetLeaderboardUseCase {
  GetLeaderboardUseCase(this._repo);

  final IRatingRepository _repo;

  Future<Either<DomainException, List<Map<String, dynamic>>>>
      execute({int limit = 50, String? cursor}) async {
    return await _repo.fetchGlobalLeaderboard(limit: limit, cursor: cursor);
  }
}
