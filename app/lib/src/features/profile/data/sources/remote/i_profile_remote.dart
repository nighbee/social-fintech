import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/user_dto.dart';

abstract interface class IProfileRemote {
  Future<Either<DomainException, UserDto>> getCurrentUser();
}
