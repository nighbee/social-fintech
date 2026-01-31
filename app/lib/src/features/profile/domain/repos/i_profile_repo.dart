import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IProfileRepo {
  Future<Either<DomainException, User>> getProfile();
}
