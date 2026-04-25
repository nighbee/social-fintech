import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CreateRequestPublishedPage extends StatelessWidget {
  const CreateRequestPublishedPage({super.key});

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
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/Task_create.png',
                            width: 104,
                            height: 104,
                            fit: BoxFit.contain,
                          ),
                          const Gap(16),
                          Text(
                            'Congratulations!',
                            style: TextStyles.titleMain.copyWith(
                              fontFamily: FontFamily.lora,
                              color: const Color(0xFFE8E8E8),
                              fontWeight: FontWeight.w600,
                              fontSize: 40 / 2,
                              height: 1.1,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            'Your request has been successfully\npublished! We\'ll be there soon.',
                            textAlign: TextAlign.center,
                            style: TextStyles.bodyMain.copyWith(
                              fontFamily: FontFamily.lora,
                              color: const Color(0xFFA3A3A3),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: CustomButton(
                      text: 'Ok',
                      onTap: () => context.go(RoutePaths.map),
                      borderRadius: 12,
                      backgroundColor: Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFFE8E8E8),
                        width: 0.5,
                      ),
                      textStyle: TextStyles.bodyMain.copyWith(
                        fontFamily: FontFamily.lora,
                        color: const Color(0xFFE8E8E8),
                        fontWeight: FontWeight.w600,
                        fontSize: 40 / 2,
                        height: 1.1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
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
