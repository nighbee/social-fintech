// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../../features/auth/data/repositories/auth_repository_impl.dart'
    as _i365;
import '../../../features/auth/data/sources/local/auth_local_impl.dart'
    as _i134;
import '../../../features/auth/data/sources/local/i_auth_local.dart' as _i964;
import '../../../features/auth/data/sources/remote/auth_remote_impl.dart'
    as _i974;
import '../../../features/auth/data/sources/remote/i_auth_remote.dart' as _i387;
import '../../../features/auth/domain/repositories/i_auth_repository.dart'
    as _i664;
import '../../../features/home/data/repositories/home_repository_impl.dart'
    as _i955;
import '../../../features/home/data/sources/remote/home_remote_impl.dart'
    as _i804;
import '../../../features/home/data/sources/remote/i_home_remote.dart' as _i482;
import '../../../features/home/domain/repositories/i_home_repository.dart'
    as _i529;
import '../../../features/home/presentation/bloc/home_bloc.dart' as _i84;
import '../../../features/map/data/repositories/map_repository_impl.dart'
    as _i770;
import '../../../features/map/data/sources/remote/i_map_remote.dart' as _i951;
import '../../../features/map/data/sources/remote/map_remote_impl.dart'
    as _i953;
import '../../../features/map/domain/repositories/i_map_repository.dart'
    as _i593;
import '../../../features/profile/data/repositories/profile_repository_impl.dart'
    as _i695;
import '../../../features/profile/data/sources/remote/i_profile_remote.dart'
    as _i964;
import '../../../features/profile/data/sources/remote/profile_remote_impl.dart'
    as _i236;
import '../../../features/profile/domain/repositories/i_profile_repository.dart'
    as _i1037;
import '../../api/client/dio/dio_client.dart' as _i1019;
import '../../api/client/dio/rest_client.dart' as _i877;
import '../../config/environment_manager.dart' as _i931;
import '../storage/app_storage/storage_service.dart' as _i6;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    gh.lazySingleton<_i6.IAppStorage>(() => _i6.AppStorageImpl());
    gh.lazySingleton<_i877.RestClient>(
      () => _i1019.DioClient(),
      instanceName: 'DioClient',
    );
    gh.lazySingleton<_i964.IAuthLocal>(
      () => _i134.AuthLocalImpl(),
      instanceName: 'AuthLocalImpl',
    );
    gh.lazySingleton<_i951.IMapRemote>(
      () =>
          _i953.MapRemoteImpl(gh<_i877.RestClient>(instanceName: 'DioClient')),
      instanceName: 'MapRemoteImpl',
    );
    gh.lazySingleton<_i482.IHomeRemote>(
      () =>
          _i804.HomeRemoteImpl(gh<_i877.RestClient>(instanceName: 'DioClient')),
      instanceName: 'HomeRemoteImpl',
    );
    gh.lazySingleton<_i931.EnvironmentManager>(
        () => _i931.EnvironmentManager(gh<_i6.IAppStorage>()));
    gh.lazySingleton<_i387.IAuthRemote>(
      () =>
          _i974.AuthRemoteImpl(gh<_i877.RestClient>(instanceName: 'DioClient')),
      instanceName: 'AuthRemoteImpl',
    );
    gh.lazySingleton<_i964.IProfileRemote>(
      () => _i236.ProfileRemoteImpl(
          gh<_i877.RestClient>(instanceName: 'DioClient')),
      instanceName: 'ProfileRemoteImpl',
    );
    gh.lazySingleton<_i664.IAuthRepository>(
      () => _i365.AuthRepositoryImpl(
        gh<_i387.IAuthRemote>(instanceName: 'AuthRemoteImpl'),
        gh<_i964.IAuthLocal>(instanceName: 'AuthLocalImpl'),
      ),
      instanceName: 'AuthRepositoryImpl',
    );
    gh.lazySingleton<_i529.IHomeRepository>(
      () => _i955.HomeRepositoryImpl(
          gh<_i482.IHomeRemote>(instanceName: 'HomeRemoteImpl')),
      instanceName: 'HomeRepositoryImpl',
    );
    gh.lazySingleton<_i593.IMapRepository>(
      () => _i770.MapRepositoryImpl(
          gh<_i951.IMapRemote>(instanceName: 'MapRemoteImpl')),
      instanceName: 'MapRepositoryImpl',
    );
    gh.lazySingleton<_i1037.IProfileRepository>(
      () => _i695.ProfileRepositoryImpl(
          gh<_i964.IProfileRemote>(instanceName: 'ProfileRemoteImpl')),
      instanceName: 'ProfileRepositoryImpl',
    );
    gh.factory<_i84.HomeBloc>(() => _i84.HomeBloc(
        gh<_i529.IHomeRepository>(instanceName: 'HomeRepositoryImpl')));
    return this;
  }
}
