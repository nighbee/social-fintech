import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/user_dto.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class IProfileRemote {
  Future<Either<DomainException, UserDto>> getProfile();
}
