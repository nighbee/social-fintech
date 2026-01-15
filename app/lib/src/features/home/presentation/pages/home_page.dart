import 'package:app/src/core/router/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BrightBund')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to BrightBund'),
            TextButton(
              onPressed: () {
                context.pushNamed(RouteNames.signup);
              },
              child: Text("Sign up"),
            ),
          ],
        ),
      ),
    );
  }
}
