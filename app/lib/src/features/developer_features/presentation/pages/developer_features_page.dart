import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/config/environment_manager.dart';
import 'package:app/src/core/service/storage/app_storage/storage_service.dart';

class DeveloperFeaturesPage extends StatefulWidget {
  const DeveloperFeaturesPage({super.key});

  @override
  State<DeveloperFeaturesPage> createState() => _DeveloperFeaturesPageState();
}

class _DeveloperFeaturesPageState extends State<DeveloperFeaturesPage> {
  late final EnvironmentManager _environmentManager;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _environmentManager = EnvironmentManager(AppStorageImpl());
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 9,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return _DeveloperItem(
                title: 'Логи через Talker',
                onTap: () => context.pushNamed(RouteNames.log),
              );
            case 1:
              return _DeveloperItem(
                title: 'Виджетбук',
                onTap: () => context.pushNamed(RouteNames.widgetBook),
              );
            case 2:
              return _DeveloperItem(
                title: 'Публичный профиль',
                subtitle: 'Тестирование просмотра профиля другого пользователя',
                onTap: () => context.goNamed(
                  RouteNames.publicProfile,
                  pathParameters: {
                    'userId': '5ff12d77-0c81-4b73-b168-85515b5d5180',
                  },
                ),
              );
            case 3:
              return _DeveloperItem(
                title: 'Ранги (Rangs)',
                subtitle: 'Система рангов и прогрессии',
                onTap: () => context.pushNamed(RouteNames.rangs),
              );
            case 4:
              return _DeveloperItem(
                title: 'Регистрация по Email',
                subtitle: 'Тестирование регистрации',
                onTap: () => context.go(RoutePaths.signupWithEmail),
              );
            case 5:
              return _DeveloperItem(
                title: 'Вход по Email',
                subtitle: 'Тестирование входа',
                onTap: () => context.go(RoutePaths.loginWithEmail),
              );
            case 6:
              return _DeveloperItem(
                title: 'Регистрация по телефону',
                subtitle: 'Тестирование регистрации',
                onTap: () => context.go(RoutePaths.signup),
              );
            case 7:
              return _DeveloperItem(
                title: 'Вход по телефону',
                subtitle: 'Тестирование входа',
                onTap: () => context.go(RoutePaths.login),
              );
            case 8:
              return _DeveloperItem(
                title:
                    'Быстрое переключение => ${_environmentManager.currentEnvironment.name}',
                subtitle: 'Переключить между dev/prod',
                trailing: _isLoading
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
              );
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
