import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:app/src/app/application.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/presentation/pages/login_page.dart';
import 'package:app/src/features/home/presentation/pages/home_page.dart';
import 'package:app/src/features/developer_features/presentation/pages/developer_features_page.dart';

part 'router_paths.dart';
part 'router_names.dart';
part 'auth_guard.dart';
part 'route_transitions.dart';
part 'route_list.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter routerProvider(AppFlavor flavor) {
  final talker = getIt<Talker>();

  final goRouter = GoRouter(
    initialLocation: RoutePaths.initial,
    debugLogDiagnostics: flavor == AppFlavor.development,
    navigatorKey: rootNavigatorKey,
    routes: _routes(talker: talker, flavor: flavor),
    observers: [TalkerRouteObserver(talker)],
  );
  return goRouter;
}
