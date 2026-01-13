import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';

class DeveloperFeaturesPage extends StatelessWidget {
  const DeveloperFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Features')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Logs'),
            subtitle: const Text('View application logs'),
            onTap: () => context.push(RoutePaths.log),
          ),
          // Add more developer features as needed
        ],
      ),
    );
  }
}

