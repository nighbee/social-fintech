import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;
  String? _lastHandledMagicLink;

  @override
  void initState() {
    super.initState();
    router = routerProvider(widget.flavor);
    _feedStateSyncService = getIt<FeedStateSyncService>();
    _feedStateSyncService.start(router);
    _startMagicLinkListener();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _feedStateSyncService.stop();
    super.dispose();
  }

  Future<void> _startMagicLinkListener() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingMagicLink(initialUri);
      }
      _deepLinkSub = _appLinks.uriLinkStream.listen(_handleIncomingMagicLink);
    } catch (_) {}
  }

  void _handleIncomingMagicLink(Uri uri) {
    final resolvedUri = _resolveMagicLink(uri);
    if (resolvedUri == null) {
      return;
    }
    final resolvedLink = resolvedUri.toString();
    if (_lastHandledMagicLink == resolvedLink) {
      return;
    }
    _lastHandledMagicLink = resolvedLink;
    getIt<AuthBloc>().add(
      AuthEvent.completeEmailMagicLink(emailLink: resolvedLink),
    );
  }

  Uri? _resolveMagicLink(Uri incoming) {
    final asString = incoming.toString();
    if (_isFirebaseEmailSignInLink(asString)) {
      return incoming;
    }

    final nestedRaw = incoming.queryParameters['link'];
    if (nestedRaw == null || nestedRaw.isEmpty) {
      return null;
    }

    final decoded = Uri.decodeComponent(nestedRaw);
    if (_isFirebaseEmailSignInLink(decoded)) {
      return Uri.tryParse(decoded);
    }
    return null;
  }

  bool _isFirebaseEmailSignInLink(String link) {
    return link.contains('mode=signIn') && link.contains('oobCode=');
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
