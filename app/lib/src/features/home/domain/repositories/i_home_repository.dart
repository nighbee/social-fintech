import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';

abstract class IHomeRepository {
  Future<Either<DomainException, List<PostEntity>>> getPosts();
}
