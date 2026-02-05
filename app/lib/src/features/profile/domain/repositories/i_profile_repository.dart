import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/domain/entities/user.dart';

abstract interface class IProfileRepository {
  /// Get current user profile data
  Future<Either<DomainException, User>> getCurrentUser();
}
