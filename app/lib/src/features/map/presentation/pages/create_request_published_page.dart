import 'dart:ui';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreateRequestPublishedPage extends StatelessWidget {
  const CreateRequestPublishedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 30,
              bottom: 200,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color.fromARGB(255, 16, 57, 21)),
                  height: 250,
                  width: 300,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Assets.icons.requestDone.svg(),
                  const Gap(16),
                  Text(
                    'Congratulations!',
                    style: TextStyles.titleMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Your request has been successfully\npublished! We\'ll be there soon.',
                    textAlign: TextAlign.center,
                    style: TextStyles.bodyMain.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  CustomOutlinedButton(
                    text: 'Ok',
                    onTap: () => context.go(RoutePaths.map),
                    borderRadius: 8,
                    backgroundColor: const Color(0xFF121418),
                    textStyle: TextStyles.bodyMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
