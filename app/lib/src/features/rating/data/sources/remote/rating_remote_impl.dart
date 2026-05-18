import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/rating/data/sources/remote/i_rating_remote.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@named
@LazySingleton(as: IRatingRemote)
class RatingRemoteImpl implements IRatingRemote {
  RatingRemoteImpl();

  @override
  Future<Either<DomainException, List<Map<String, dynamic>>>>
      getGlobalLeaderboard({int limit = 50, String? cursor}) async {
    final items = <Map<String, dynamic>>[
      {
        'name': 'Zhandos Berik',
        'rank': 1,
        'honor': 950,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
      },
      {
        'name': 'Auelkhanova Amina',
        'rank': 2,
        'honor': 900,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
      },
      {
        'name': 'Zhannsa Berik',
        'rank': 3,
        'honor': 800,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
      },
      {
        'name': 'Kundyz Akzhan',
        'rank': 4,
        'honor': 75,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
      },
      {
        'name': 'Kundyz Akzhan',
        'rank': 5,
        'honor': 29,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
      },
      {
        'name': 'You',
        'rank': 10,
        'honor': 26,
        'rank_name': 'Moonstone',
        'rank_tier': 'Intention',
        'rank_grade': 'A',
        'is_current_user': true,
      },
    ];

    return Right(items.take(limit).toList());
  }
}
