import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';

abstract class IRatingRemote {
  Future<Either<DomainException, List<Map<String, dynamic>>>>
      getGlobalLeaderboard({int limit, String? cursor});
}
