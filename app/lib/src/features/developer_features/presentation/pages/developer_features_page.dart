import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/config/environment_manager.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';
import 'package:app/src/core/widgets/list_item/custom_list_item.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';

class DeveloperFeaturesPage extends StatefulWidget {
  const DeveloperFeaturesPage({super.key});

  @override
  State<DeveloperFeaturesPage> createState() => _DeveloperFeaturesPageState();
}

class _DeveloperFeaturesPageState extends State<DeveloperFeaturesPage> {
  late final EnvironmentManager _environmentManager;
  bool _isLoading = false;
  late final TextEditingController _userIdController;

  @override
  void initState() {
    super.initState();
    _environmentManager = EnvironmentManager(AppStorageImpl());
    _userIdController = TextEditingController(
      text: '5ff12d77-0c81-4b73-b168-85515b5d5180',
    );
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _toggleEnvironment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final EnvironmentType nextEnv = _environmentManager.isDevelopment
          ? EnvironmentType.prod
          : EnvironmentType.dev;
      await _environmentManager.switchEnvironment(nextEnv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Переключено на ${_environmentManager.currentEnvironment.name}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при переключении: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Фичи разработчика')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomListItem(
            title: 'Логи через Talker',
            isStroke: true,
            iconRight: true,
            onTap: () => context.pushNamed(RouteNames.log),
          ),
          CustomListItem(
            title: 'Виджетбук',
            isStroke: true,
            iconRight: true,
            onTap: () => context.pushNamed(RouteNames.widgetBook),
          ),
          CustomListItem(
            title: 'Feed (Home)',
            subtitle: 'Открыть текущую ленту',
            isStroke: true,
            iconRight: true,
            onTap: () => context.go(RoutePaths.feedPreview),
          ),
          // User Id Input Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Публичный профиль',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _userIdController,
                        decoration: const InputDecoration(
                          labelText: 'User ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (_userIdController.text.isNotEmpty) {
                          context.pushNamed(
                            RouteNames.publicProfile,
                            pathParameters: {'userId': _userIdController.text},
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          CustomListItem(
            title: 'Ранги (Rangs)',
            subtitle: 'Система рангов и прогрессии',
            isStroke: true,
            iconRight: true,
            onTap: () => context.pushNamed(RouteNames.rangs),
          ),
          CustomListItem(
            title: 'Leaderboard Admin',
            subtitle: 'Redis scopes, add-user, verify rating',
            isStroke: true,
            iconRight: true,
            onTap: () => context.pushNamed(RouteNames.leaderboardAdmin),
          ),
          CustomListItem(
            title: 'Регистрация по Email',
            subtitle: 'Тестирование регистрации',
            isStroke: true,
            iconRight: true,
            onTap: () => context.go(RoutePaths.signupWithEmail),
          ),
          CustomListItem(
            title: 'Вход по Email',
            subtitle: 'Тестирование входа',
            isStroke: true,
            iconRight: true,
            onTap: () => context.go(RoutePaths.loginWithEmail),
          ),
          CustomListItem(
            title: 'Регистрация по телефону',
            subtitle: 'Тестирование регистрации',
            isStroke: true,
            iconRight: true,
            onTap: () => context.go(RoutePaths.signup),
          ),
          CustomListItem(
            title: 'Вход по телефону',
            subtitle: 'Тестирование входа',
            isStroke: true,
            iconRight: true,
            onTap: () => context.go(RoutePaths.login),
          ),
          CustomListItem(
            title:
                'Быстрое переключение => ${_environmentManager.currentEnvironment.name}',
            subtitle: 'Переключить между dev/prod',
            isStroke: true,
            widgetRight: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blueGrey,
                    ),
                  )
                : const Icon(
                    Icons.swap_horiz,
                    color: Colors.blueGrey,
                    size: 20,
                  ),
            onTap: _isLoading ? null : _toggleEnvironment,
          ),
          const SizedBox(height: 24),
          CustomListItem(
            title: 'Выйти из аккаунта',
            subtitle: 'Logout',
            isStroke: true,
            iconRight: true,
            color: Colors.red,
            onTap: () {
              getIt<AuthBloc>().add(const AuthEvent.logout());
              context.go(RoutePaths.loginWithEmail);
            },
          ),
        ],
      ),
    );
  }
}
