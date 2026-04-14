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
      backgroundColor: const Color(0xFF12161B),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF12161B),
                    Color(0xFF0A0D12),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0.56),
                    radius: 0.9,
                    colors: [
                      Color(0x4A214D36),
                      Color(0x1A132820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-1.02, 0.08),
                    radius: 1.08,
                    colors: [
                      Color(0x2E1E5A37),
                      Color(0x10122820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(1.02, 0.08),
                    radius: 1.08,
                    colors: [
                      Color(0x2E1E5A37),
                      Color(0x10122820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Assets.icons.requestCancel.svg(
                    width: 104,
                    height: 104,
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
                    text: 'Ok',
                    onTap: () => context.go(RoutePaths.map),
                    borderRadius: 8,
                    backgroundColor: Colors.transparent,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    textStyle: TextStyles.bodyMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
