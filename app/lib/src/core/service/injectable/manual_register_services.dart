import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/service/injectable/service_register_proxy.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';

Future<void> manualRegisterServices() async {
  getIt.registerBloc<ProfileBloc>(
    () => ProfileBloc(
      getIt<IProfileRepository>(instanceName: 'ProfileRepositoryImpl'),
    ),
  );
}
