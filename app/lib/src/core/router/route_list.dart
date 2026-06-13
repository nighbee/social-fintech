part of 'router.dart';

NoTransitionPage<void> _darkPage(
  GoRouterState state,
  Widget child,
) {
  return NoTransitionPage<void>(
    key: state.pageKey,
    child: ColoredBox(
      color: AppColors.mainBackground,
      child: child,
    ),
  );
}

NoTransitionPage<void> _authPage(
  GoRouterState state,
  Widget child,
) =>
    _darkPage(state, child);

class _AppBackNavigationScope extends StatefulWidget {
  const _AppBackNavigationScope({
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  State<_AppBackNavigationScope> createState() =>
      _AppBackNavigationScopeState();
}

class _AppBackNavigationScopeState extends State<_AppBackNavigationScope> {
  static const Duration _exitConfirmationWindow = Duration(seconds: 2);

  DateTime? _lastBackPressedAt;

  bool get _isHome => widget.location == RoutePaths.home;

  bool get _isMainTabRoot =>
      widget.location == RoutePaths.home ||
      widget.location == RoutePaths.map ||
      widget.location == RoutePaths.rating ||
      widget.location == RoutePaths.chats ||
      widget.location == RoutePaths.profile;

  @override
  void didUpdateWidget(covariant _AppBackNavigationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) {
      _lastBackPressedAt = null;
    }
  }

  void _handleRootBack() {
    if (!_isHome) {
      context.go(RoutePaths.home);
      return;
    }

    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= _exitConfirmationWindow;

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: _exitConfirmationWindow,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isMainTabRoot,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_isMainTabRoot) return;
        _handleRootBack();
      },
      child: widget.child,
    );
  }
}

List<RouteBase> _routes({required Talker talker, required AppFlavor flavor}) =>
    <RouteBase>[
      // Initial route - redirects to home
      GoRoute(
        path: RoutePaths.initial,
        name: RouteNames.initial,
        redirect: (context, state) {
          return RoutePaths.home;
        },
      ),

      // Developer features route (outside shell for easy access)
      GoRoute(
        path: RoutePaths.developerFeatures,
        name: RouteNames.developerFeatures,
        builder: (context, state) => const DeveloperFeaturesPage(),
        routes: [
          GoRoute(
            path: 'log',
            name: RouteNames.log,
            builder: (context, state) => TalkerScreen(
              talker: talker,
              theme: TalkerScreenTheme.fromTheme(Theme.of(context), {
                TalkerLogType.blocEvent.key: Colors.green,
                TalkerLogType.blocTransition.key: Colors.green,
                TalkerLogType.httpResponse.key: Colors.green,
              }),
            ),
          ),
          GoRoute(
            path: 'widget_book',
            name: RouteNames.widgetBook,
            builder: (context, state) => const WidgetBookPage(),
          ),
          GoRoute(
            path: 'rangs',
            name: RouteNames.rangs,
            builder: (context, state) => const RangsPage(),
          ),
          GoRoute(
            path: 'leaderboard_admin',
            name: RouteNames.leaderboardAdmin,
            builder: (context, state) => const LeaderboardAdminPage(),
          ),
        ],
      ),

      GoRoute(
        path: RoutePaths.feedPreview,
        name: RouteNames.feedPreview,
        builder: (context, state) => const FeedPage(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        redirect: AuthGuard,
        pageBuilder: (context, state) =>
            _darkPage(state, const NotificationsPage()),
        routes: [
          GoRoute(
            path: 'settings',
            name: RouteNames.notificationSettings,
            parentNavigatorKey: rootNavigatorKey,
            redirect: AuthGuard,
            pageBuilder: (context, state) =>
                _darkPage(state, const NotificationSettingsPage()),
          ),
        ],
      ),

      // Main app routes wrapped in StatefulShellRoute for LogPushButton
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) {
          return _AppBackNavigationScope(
            location: state.uri.path,
            child: ColoredBox(
              color: AppColors.mainBackground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  // Show LogPushButton only in development flavor
                  if (flavor == AppFlavor.development) const LogPushButton(),
                ],
              ),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            observers: [TalkerRouteObserver(talker)],
            routes: [
              // Auth routes - Signup
              GoRoute(
                path: RoutePaths.signup,
                name: RouteNames.signup,
                pageBuilder: (context, state) =>
                    _authPage(state, const SignupWithNumberPage()),
              ),
              GoRoute(
                path: RoutePaths.signupWithEmail,
                name: RouteNames.signupWithEmail,
                pageBuilder: (context, state) =>
                    _authPage(state, const SignupWithEmailPage()),
              ),
              GoRoute(
                path: RoutePaths.code,
                name: RouteNames.code,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _authPage(
                    state,
                    CodePage(
                      verificationId: extra?['verificationId'] ?? '',
                      phoneNumber: extra?['phoneNumber'] ?? '',
                      isLogin: extra?['isLogin'] ?? true,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.info,
                name: RouteNames.info,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _authPage(
                    state,
                    InfoPage(
                      email: extra?['email'] as String?,
                      password: extra?['password'] as String?,
                      phoneNumber: extra?['phoneNumber'] as String?,
                      firebaseIdToken: extra?['firebaseIdToken'] as String?,
                      firebaseAuthProvider:
                          extra?['firebaseAuthProvider'] as String?,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.referal,
                name: RouteNames.referal,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _authPage(
                    state,
                    ReferalPage(
                      email: extra?['email'] as String?,
                      password: extra?['password'] as String?,
                      phoneNumber: extra?['phoneNumber'] as String?,
                      firebaseIdToken: extra?['firebaseIdToken'] as String?,
                      firebaseAuthProvider:
                          extra?['firebaseAuthProvider'] as String?,
                      firstName: extra?['firstName'] as String?,
                      lastName: extra?['lastName'] as String?,
                      dateOfBirth: extra?['dateOfBirth'] as String?,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.createPassword,
                name: RouteNames.createPassword,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final email = extra?['email'] as String? ?? '';
                  return _authPage(
                    state,
                    CreatePasswordPage(email: email),
                  );
                },
              ),
              // Auth routes - Login
              GoRoute(
                path: RoutePaths.login,
                name: RouteNames.login,
                pageBuilder: (context, state) =>
                    _authPage(state, const LoginWithNumberPage()),
              ),
              GoRoute(
                path: RoutePaths.loginWithEmail,
                name: RouteNames.loginWithEmail,
                pageBuilder: (context, state) =>
                    _authPage(state, const LoginWithEmailPage()),
              ),
              GoRoute(
                path: RoutePaths.emailEntry,
                name: RouteNames.emailEntry,
                pageBuilder: (context, state) =>
                    _authPage(state, const EmailEntryPage()),
              ),
              GoRoute(
                path: RoutePaths.emailPassword,
                name: RouteNames.emailPassword,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _authPage(
                    state,
                    EmailPasswordPage(
                      email: extra?['email'] ?? '',
                      isNewUser: extra?['isNewUser'] ?? false,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.loginCode,
                name: RouteNames.loginCode,
                pageBuilder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return _authPage(
                    state,
                    LoginCodePage(
                      verificationId: extra?['verificationId'] ?? '',
                      phoneNumber: extra?['phoneNumber'] ?? '',
                      isLogin: extra?['isLogin'] ?? true,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.changePassword,
                name: RouteNames.changePassword,
                pageBuilder: (context, state) =>
                    _authPage(state, const ChangePasswordPage()),
              ),

              // Home route (protected by auth guard)
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  final extra = state.extra;
                  final map = extra is Map<String, dynamic>
                      ? extra
                      : <String, dynamic>{};
                  final showReferralInviteActivated =
                      map['showReferralInviteActivated'] as bool? ?? false;

                  return NoTransitionPage(
                    child: HomePage(
                      showReferralInviteActivatedOnOpen:
                          showReferralInviteActivated,
                    ),
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.createPost,
                name: RouteNames.createPost,
                redirect: AuthGuard,
                builder: (context, state) => const CreatePostPage(),
              ),
              GoRoute(
                path: RoutePaths.search,
                name: RouteNames.search,
                redirect: AuthGuard,
                builder: (context, state) => const SearchPage(),
              ),
              GoRoute(
                path: RoutePaths.store,
                name: RouteNames.store,
                redirect: AuthGuard,
                builder: (context, state) => const StorePage(),
              ),
              GoRoute(
                path: RoutePaths.publicProfile,
                name: RouteNames.publicProfile,
                redirect: AuthGuard,
                builder: (context, state) {
                  final userId = state.pathParameters['userId'] ?? '';
                  return PublicProfilePage(userId: userId);
                },
              ),

              // Map route (protected by auth guard)
              GoRoute(
                path: RoutePaths.map,
                name: RouteNames.map,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: MapPage());
                },
              ),
              GoRoute(
                path: RoutePaths.mapCreateRequest,
                name: RouteNames.mapCreateRequest,
                redirect: AuthGuard,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final latitude =
                      (extra?['latitude'] as num?)?.toDouble() ?? 50.4501;
                  final longitude =
                      (extra?['longitude'] as num?)?.toDouble() ?? 30.5234;
                  return CreateRequestPage(
                    latitude: latitude,
                    longitude: longitude,
                  );
                },
              ),
              GoRoute(
                path: RoutePaths.mapCreateRequestPublished,
                name: RouteNames.mapCreateRequestPublished,
                redirect: AuthGuard,
                builder: (context, state) => const CreateRequestPublishedPage(),
              ),
              GoRoute(
                path: RoutePaths.mapRequestCanceled,
                name: RouteNames.mapRequestCanceled,
                redirect: AuthGuard,
                builder: (context, state) => const MapRequestCanceledPage(),
              ),
              GoRoute(
                path: RoutePaths.mapRequestClosed,
                name: RouteNames.mapRequestClosed,
                redirect: AuthGuard,
                builder: (context, state) => const MapRequestClosedPage(),
              ),
              GoRoute(
                path: RoutePaths.mapRequestCompleted,
                name: RouteNames.mapRequestCompleted,
                redirect: AuthGuard,
                builder: (context, state) => const MapRequestCompletedPage(),
              ),

              // Rating route (protected by auth guard)
              GoRoute(
                path: RoutePaths.rating,
                name: RouteNames.rating,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: RatingPage());
                },
              ),

              // Chats route (protected by auth guard)
              GoRoute(
                path: RoutePaths.chats,
                name: RouteNames.chats,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return const NoTransitionPage(child: ChatsPage());
                },
                routes: [
                  GoRoute(
                    path: 'requests',
                    name: RouteNames.chatRequests,
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: AuthGuard,
                    pageBuilder: (context, state) {
                      return const NoTransitionPage(child: ChatRequestsPage());
                    },
                  ),
                ],
              ),

              // Profile route (protected by auth guard)
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                redirect: AuthGuard,
                pageBuilder: (context, state) {
                  return NoTransitionPage(child: ProfilePage());
                },
                routes: [
                  GoRoute(
                    path: 'stats',
                    name: RouteNames.profileStats,
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: AuthGuard,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      return UserStatsPage(
                        userId: map['userId'] as String?,
                        isCurrentUser: map['isCurrentUser'] as bool? ?? true,
                        rankTier: map['rankTier'] as String? ?? '',
                        reputationScore: map['reputationScore'] as int? ?? 0,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'settings',
                    name: RouteNames.settings,
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: AuthGuard,
                    pageBuilder: (context, state) {
                      final extra = state.extra;
                      final map = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      final userId = map['userId'] as String?;
                      return _darkPage(
                        state,
                        SettingsPage(currentUserId: userId),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'feed-time-limit',
                        name: RouteNames.profileFeedTimeLimit,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final map = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          final initial =
                              map['initialSelectionLabel'] as String? ??
                                  'No limit';
                          return _darkPage(
                            state,
                            FeedTimeLimitPage(
                              initialSelectionLabel: initial,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'location-access',
                        name: RouteNames.profileLocationAccess,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final map = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          final initialLabel =
                              map['initialSelectionLabel'] as String? ??
                                  'Never';
                          final initialPrecise =
                              map['initialPreciseLocationEnabled'] as bool? ??
                                  false;
                          return _darkPage(
                            state,
                            LocationAccessPage(
                              initialSelectionLabel: initialLabel,
                              initialPreciseLocationEnabled: initialPrecise,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'invite-golden-honor',
                        name: RouteNames.profileInviteGoldenHonor,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final map = extra is Map<String, dynamic>
                              ? extra
                              : <String, dynamic>{};
                          final userId = map['userId'] as String?;
                          return _darkPage(
                            state,
                            InviteGoldenHonorPage(currentUserId: userId),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'enter-invite-code',
                        name: RouteNames.profileEnterInviteCode,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => _darkPage(
                          state,
                          const EnterInviteCodePage(),
                        ),
                      ),
                      GoRoute(
                        path: 'contact-us',
                        name: RouteNames.profileContactUs,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _darkPage(state, const ContactUsPage()),
                      ),
                      GoRoute(
                        path: 'report-bug',
                        name: RouteNames.profileReportBug,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _darkPage(state, const ReportBugPage()),
                      ),
                      GoRoute(
                        path: 'terms-conditions',
                        name: RouteNames.profileTermsConditions,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => _darkPage(
                          state,
                          const TermsConditionsPage(),
                        ),
                      ),
                      GoRoute(
                        path: 'security',
                        name: RouteNames.profileSecurity,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _darkPage(state, const SecurityPage()),
                        routes: [
                          GoRoute(
                            path: 'change-password',
                            name: RouteNames.profileSecurityChangePassword,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              const ProfileChangePasswordPage(),
                            ),
                          ),
                          GoRoute(
                            path: 'two-factor',
                            name: RouteNames.profileSecurityTwoFactor,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) {
                              final extra = state.extra;
                              final map = extra is Map<String, dynamic>
                                  ? extra
                                  : <String, dynamic>{};
                              final ids =
                                  (map['selectedMethodIds'] as List<dynamic>?)
                                          ?.whereType<String>()
                                          .toList() ??
                                      <String>[];
                              return _darkPage(
                                state,
                                TwoFactorAuthenticationPage(
                                  initialSelectedMethodIds: ids,
                                ),
                              );
                            },
                          ),
                          GoRoute(
                            path: 'active-sessions',
                            name: RouteNames.profileSecurityActiveSessions,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) {
                              final extra = state.extra;
                              final map = extra is Map<String, dynamic>
                                  ? extra
                                  : <String, dynamic>{};
                              final raw = map['sessions'];
                              final sessions = raw is List
                                  ? raw
                                      .map(
                                        (e) => Map<String, dynamic>.from(
                                          e as Map<dynamic, dynamic>,
                                        ),
                                      )
                                      .toList()
                                  : <Map<String, dynamic>>[];
                              return _darkPage(
                                state,
                                ActiveSessionsPage(sessions: sessions),
                              );
                            },
                          ),
                          GoRoute(
                            path: 'delete-account',
                            name: RouteNames.profileSecurityDeleteAccount,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              DeleteAccountReasonPage(
                                flowData: DeleteAccountFlowData.fromExtra(
                                  state.extra,
                                ),
                              ),
                            ),
                            routes: [
                              GoRoute(
                                path: 'verify-password',
                                name: RouteNames
                                    .profileSecurityDeleteAccountPassword,
                                parentNavigatorKey: rootNavigatorKey,
                                pageBuilder: (context, state) => _darkPage(
                                  state,
                                  DeleteAccountPasswordPage(
                                    flowData: DeleteAccountFlowData.fromExtra(
                                      state.extra,
                                    ),
                                  ),
                                ),
                              ),
                              GoRoute(
                                path: 'verify-otp',
                                name:
                                    RouteNames.profileSecurityDeleteAccountOtp,
                                parentNavigatorKey: rootNavigatorKey,
                                pageBuilder: (context, state) => _darkPage(
                                  state,
                                  DeleteAccountOtpPage(
                                    flowData: DeleteAccountFlowData.fromExtra(
                                      state.extra,
                                    ),
                                  ),
                                ),
                              ),
                              GoRoute(
                                path: 'confirm',
                                name: RouteNames
                                    .profileSecurityDeleteAccountConfirm,
                                parentNavigatorKey: rootNavigatorKey,
                                pageBuilder: (context, state) => _darkPage(
                                  state,
                                  DeleteAccountConfirmationPage(
                                    flowData: DeleteAccountFlowData.fromExtra(
                                      state.extra,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'interactions',
                        name: RouteNames.profileInteractions,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _darkPage(state, const InteractionsPage()),
                        routes: [
                          GoRoute(
                            path: 'messages',
                            name: RouteNames.profileInteractionMessages,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              const MessagesInteractionPage(),
                            ),
                            routes: [
                              GoRoute(
                                path: 'keywords',
                                name: RouteNames.profileMessageFilteredKeywords,
                                parentNavigatorKey: rootNavigatorKey,
                                pageBuilder: (context, state) => _darkPage(
                                  state,
                                  const FilteredKeywordsPage(),
                                ),
                              ),
                            ],
                          ),
                          GoRoute(
                            path: 'comments',
                            name: RouteNames.profileInteractionComments,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              const CommentsInteractionPage(),
                            ),
                          ),
                          GoRoute(
                            path: 'mentions',
                            name: RouteNames.profileInteractionMentions,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              const MentionsInteractionPage(),
                            ),
                          ),
                          GoRoute(
                            path: 'blocked',
                            name: RouteNames.profileBlockedAccounts,
                            parentNavigatorKey: rootNavigatorKey,
                            pageBuilder: (context, state) => _darkPage(
                              state,
                              const BlockedAccountsPage(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: RoutePaths.editProfile,
                    name: RouteNames.editProfile,
                    builder: (context, state) => const EditProfilePage(),
                  ),
                  GoRoute(
                    path: RoutePaths.editProfileNickname,
                    name: RouteNames.editProfileNickname,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      final displayName = map['displayName'] as String? ?? '';
                      final userId = map['userId'] as String? ?? '';
                      return EditProfileNicknamePage(
                        initialDisplayName: displayName,
                        currentUserId: userId,
                      );
                    },
                  ),
                  GoRoute(
                    path: RoutePaths.editProfileBio,
                    name: RouteNames.editProfileBio,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      final bio = map['bio'] as String? ?? '';
                      return EditProfileBioPage(initialBio: bio);
                    },
                  ),
                  GoRoute(
                    path: 'publications',
                    name: RouteNames.profilePublications,
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: AuthGuard,
                    builder: (context, state) {
                      final extra = state.extra;
                      final map = extra is Map<String, dynamic>
                          ? extra
                          : <String, dynamic>{};
                      final displayName = map['displayName'] as String? ?? '';
                      final initialPostId =
                          map['initialPostId'] as String? ?? '';
                      final isCurrentUser =
                          map['isCurrentUser'] as bool? ?? true;
                      final userId = map['userId'] as String?;
                      return ProfilePublicationsPage(
                        displayName: displayName,
                        initialPostId: initialPostId,
                        isCurrentUser: isCurrentUser,
                        userId: userId,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'allies',
                    name: RouteNames.allies,
                    redirect: AuthGuard,
                    builder: (context, state) => const AlliesPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Диалог: вне StatefulShell — иначе у Scaffold ломаются constraints (пустое тело, композер «не там»).
      GoRoute(
        path: RoutePaths.chatThread,
        name: RouteNames.chatConversation,
        parentNavigatorKey: rootNavigatorKey,
        redirect: AuthGuard,
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['chatId'] ?? '';
          final extra = state.extra;
          final ChatThreadPreview? preview =
              extra is ChatThreadPreview ? extra : null;
          return NoTransitionPage(
            child: ChatConversationPage(
              chatId: chatId,
              threadPreview: preview,
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'forward',
            name: RouteNames.chatConversationForward,
            parentNavigatorKey: rootNavigatorKey,
            redirect: AuthGuard,
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId'] ?? '';
              final extra = state.extra;
              final ChatThreadPreview? preview =
                  extra is ChatThreadPreview ? extra : null;
              return NoTransitionPage(
                child: ChatForwardMessagePage(
                  chatId: chatId,
                  threadPreview: preview,
                ),
              );
            },
          ),
          GoRoute(
            path: 'select',
            name: RouteNames.chatConversationSelect,
            parentNavigatorKey: rootNavigatorKey,
            redirect: AuthGuard,
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId'] ?? '';
              final extra = state.extra;
              final ChatThreadPreview? preview =
                  extra is ChatThreadPreview ? extra : null;
              return NoTransitionPage(
                child: ChatSelectMessagePage(
                  chatId: chatId,
                  threadPreview: preview,
                ),
              );
            },
          ),
          GoRoute(
            path: 'blocked',
            name: RouteNames.chatConversationBlocked,
            parentNavigatorKey: rootNavigatorKey,
            redirect: AuthGuard,
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId'] ?? '';
              final extra = state.extra;
              final ChatThreadPreview? preview =
                  extra is ChatThreadPreview ? extra : null;
              return NoTransitionPage(
                child: ChatBlockedPage(
                  chatId: chatId,
                  threadPreview: preview,
                ),
              );
            },
          ),
          GoRoute(
            path: 'deleted',
            name: RouteNames.chatConversationDeleted,
            parentNavigatorKey: rootNavigatorKey,
            redirect: AuthGuard,
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId'] ?? '';
              final extra = state.extra;
              final ChatThreadPreview? preview =
                  extra is ChatThreadPreview ? extra : null;
              return NoTransitionPage(
                child: ChatDeletedPage(
                  chatId: chatId,
                  threadPreview: preview,
                ),
              );
            },
          ),
        ],
      ),
    ];

class LogPushButton extends StatelessWidget {
  const LogPushButton({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Positioned(
      right: 0,
      top: (height - (height / 4)),
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.developerFeatures),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: const Icon(Icons.logo_dev_rounded),
        ),
      ),
    );
  }
}
