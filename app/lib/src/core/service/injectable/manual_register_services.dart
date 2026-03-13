import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/core/service/location/i_location_service.dart';
import 'package:app/src/core/service/location/location_service_impl.dart';
import 'package:app/src/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/map/domain/repositories/i_map_repository.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
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

  if (getIt.isRegistered<HomeBloc>()) {
    getIt.unregister<HomeBloc>();
  }
  getIt.registerBloc<HomeBloc>(
    () => HomeBloc(
      getIt<IHomeRepository>(instanceName: 'HomeRepositoryImpl'),
      getIt<IProfileRepository>(instanceName: 'ProfileRepositoryImpl'),
    ),
  );

  if (getIt.isRegistered<MapBloc>()) {
    getIt.unregister<MapBloc>();
  }
  getIt.registerBloc<MapBloc>(
    () => MapBloc(
      getIt<IMapRepository>(instanceName: 'MapRepositoryImpl'),
    ),
  );

  if (getIt.isRegistered<ILocationService>(
      instanceName: 'LocationServiceImpl')) {
    getIt.unregister<ILocationService>(instanceName: 'LocationServiceImpl');
  }
  getIt.registerLazySingleton<ILocationService>(
    () => LocationServiceImpl(),
    instanceName: 'LocationServiceImpl',
  );
}
