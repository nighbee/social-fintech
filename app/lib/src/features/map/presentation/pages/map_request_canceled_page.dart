import 'dart:ui';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class MapRequestCanceledPage extends StatelessWidget {
  const MapRequestCanceledPage({super.key});

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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 16, 57, 21),
                  ),
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
                  Assets.icons.requestCancel.svg(
                    width: 110,
                    height: 110,
                    color: AppColors.colorffffffff,
                  ),
                  const Gap(16),
                  Text(
                    'Request canceled',
                    style: TextStyles.titleTag.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Your request has been successfully canceled.',
                    textAlign: TextAlign.center,
                    style: TextStyles.bodyMain.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'ok',
                    onTap: () => context.go(RoutePaths.map),
                    borderRadius: 8,
                    backgroundColor: const Color(0xFF121418),
                    border: Border.all(color: Colors.white24),
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
