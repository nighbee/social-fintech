import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/data/models/post_dto.dart';

abstract class IHomeRemote {
  Future<Either<DomainException, List<PostDto>>> getPosts();
}
