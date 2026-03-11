import 'dart:async';
import 'package:app/src/features/profile/presentation/pages/profile_page.dart';
import 'package:app/src/features/profile/presentation/pages/allies_page.dart';
import 'package:app/src/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:app/src/features/profile/presentation/pages/public_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:app/src/app/application.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/presentation/pages/signup_with_number_page.dart';
import 'package:app/src/features/auth/presentation/pages/signup_with_email_page.dart';
import 'package:app/src/features/auth/presentation/pages/login_with_number_page.dart';
import 'package:app/src/features/auth/presentation/pages/login_with_email_page.dart';
import 'package:app/src/features/auth/presentation/pages/login_code_page.dart';
import 'package:app/src/features/auth/presentation/pages/code_page.dart';
import 'package:app/src/features/auth/presentation/pages/email_entry_page.dart';
import 'package:app/src/features/auth/presentation/pages/email_password_page.dart';
import 'package:app/src/features/auth/presentation/pages/info_page.dart';
import 'package:app/src/features/auth/presentation/pages/referal_page.dart';
import 'package:app/src/features/auth/presentation/pages/create_password_page.dart';
import 'package:app/src/features/auth/presentation/pages/change_password_page.dart';
import 'package:app/src/features/home/presentation/pages/home_page.dart';
import 'package:app/src/features/home/presentation/pages/create_post_page.dart';
import 'package:app/src/features/map/presentation/pages/create_request_page.dart';
import 'package:app/src/features/map/presentation/pages/create_request_published_page.dart';
import 'package:app/src/features/map/presentation/pages/map_request_canceled_page.dart';
import 'package:app/src/features/map/presentation/pages/map_request_completed_page.dart';
import 'package:app/src/features/map/presentation/pages/map_page.dart';
import 'package:app/src/features/rating/presentation/pages/rating_page.dart';
import 'package:app/src/features/chats/presentation/pages/chats_page.dart';
import 'package:app/src/features/home/presentation/pages/notifications_page.dart';
import 'package:app/src/features/developer_features/presentation/pages/developer_features_page.dart';
import 'package:app/src/features/developer_features/presentation/pages/widget_book_page.dart';
import 'package:app/src/features/profile/presentation/pages/ranks_page.dart';
import 'package:app/src/core/service/storage/secure_storage/secure_storage_service_impl.dart';
import 'package:app/src/core/utils/loggers/log.dart';

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

