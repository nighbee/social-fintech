import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';

Future<void> manualRegisterServices() async {
  getIt.registerBloc<AuthBloc>(
    () => AuthBloc(
      getIt<IAuthRepository>(instanceName: 'AuthRepositoryImpl'),
    ),
  );

  getIt.registerBloc<ProfileBloc>(
    () => ProfileBloc(
      getIt<IProfileRepository>(instanceName: 'ProfileRepositoryImpl'),
    ),
  );
}
