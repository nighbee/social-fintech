import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class MapRequestCompletedPage extends StatelessWidget {
  const MapRequestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white70,
                  size: 44,
                ),
              ),
              const Gap(16),
              Text(
                'Well done!',
                style: TextStyles.titleTag.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(8),
              Text(
                'The request has been closed successfully.',
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
      ),
    );
  }
}
