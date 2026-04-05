import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/service/feed/feed_state_sync_service.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';

part 'flavor_builds.dart';

class MainApp extends StatefulWidget {
  const MainApp({required this.flavor, super.key});

  final AppFlavor flavor;

  void run() => runApp(this);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final GoRouter router;
  late final FeedStateSyncService _feedStateSyncService;

  @override
  void initState() {
    super.initState();
    router = routerProvider(widget.flavor);
    _feedStateSyncService = getIt<FeedStateSyncService>();
    _feedStateSyncService.start(router);
  }

  @override
  void dispose() {
    _feedStateSyncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseBlocWidget<AuthBloc, AuthEvent, AuthState>(
      bloc: getIt<AuthBloc>(),
      builder: (context, state, bloc) {
        return BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
          bloc: getIt<ProfileBloc>(),
          starterEvent: const ProfileEvent.loadProfile(),
          builder: (context, state, bloc) {
            return _buildApp(
              flavor: widget.flavor,
              router: router,
              languageCode: 'en',
            );
          },
        );
      },
    );
  }
}
