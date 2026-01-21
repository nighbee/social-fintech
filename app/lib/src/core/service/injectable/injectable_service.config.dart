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
import '../../../features/auth/presentation/bloc/auth_bloc.dart' as _i748;
import '../../../features/profile/data/datasources/i_profile_remote.dart'
    as _i132;
import '../../../features/profile/data/datasources/profile_remote_impl.dart'
    as _i169;
import '../../../features/profile/data/repos/profile_repo_impl.dart' as _i715;
import '../../../features/profile/domain/repos/i_profile_repo.dart' as _i418;
import '../../../features/profile/presentation/bloc/profile_bloc.dart' as _i428;
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
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i6.IAppStorage>(() => _i6.AppStorageImpl());
    gh.lazySingleton<_i964.IAuthLocal>(
      () => _i134.AuthLocalImpl(),
      instanceName: 'AuthLocalImpl',
    );
    gh.lazySingleton<_i931.EnvironmentManager>(
      () => _i931.EnvironmentManager(gh<_i6.IAppStorage>()),
    );
    gh.lazySingleton<_i877.RestClient>(
      () => _i1019.DioClient(gh<_i931.EnvironmentManager>()),
      instanceName: 'DioClient',
    );
    gh.lazySingleton<_i387.IAuthRemote>(
      () =>
          _i974.AuthRemoteImpl(gh<_i877.RestClient>(instanceName: 'DioClient')),
      instanceName: 'AuthRemoteImpl',
    );
    gh.lazySingleton<_i132.IProfileRemote>(
      () => _i169.ProfileRemoteImpl(
        gh<_i877.RestClient>(instanceName: 'DioClient'),
      ),
      instanceName: 'ProfileRemoteImpl',
    );
    gh.lazySingleton<_i418.IProfileRepo>(
      () => _i715.ProfileRepositoryImpl(
        gh<_i132.IProfileRemote>(instanceName: 'ProfileRemoteImpl'),
      ),
      instanceName: 'ProfileRepositoryImpl',
    );
    gh.factory<_i428.ProfileBloc>(
      () => _i428.ProfileBloc(
        gh<_i418.IProfileRepo>(instanceName: 'ProfileRepositoryImpl'),
      ),
    );
    gh.lazySingleton<_i664.IAuthRepository>(
      () => _i365.AuthRepositoryImpl(
        gh<_i387.IAuthRemote>(instanceName: 'AuthRemoteImpl'),
        gh<_i964.IAuthLocal>(instanceName: 'AuthLocalImpl'),
      ),
      instanceName: 'AuthRepositoryImpl',
    );
    gh.factory<_i748.AuthBloc>(
      () => _i748.AuthBloc(
        gh<_i664.IAuthRepository>(instanceName: 'AuthRepositoryImpl'),
      ),
    );

    return this;
  }
}
