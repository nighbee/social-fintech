import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';

class DeveloperFeaturesPage extends StatelessWidget {
  const DeveloperFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Режим разработчика')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
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
                title: 'Компоненты',
                onTap: () => context.pushNamed(RouteNames.widgetBook),
              );
            case 2:
              return _DeveloperItem(
                title: 'Быстрое переключение ⇒ dev',
                subtitle: 'Переключить между dev/prod',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пока не реализовано')),
                  );
                },
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
  const _DeveloperItem({required this.title, this.subtitle, this.onTap});

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}
