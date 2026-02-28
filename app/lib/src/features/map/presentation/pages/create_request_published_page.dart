import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/router/router.dart';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3FA8FF), width: 2),
                  color: const Color(0xFF0F1B22),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const Gap(16),
              Text(
                'Congratulations!',
                style: TextStyles.titleTag.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
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
              CustomButton(
                text: 'Ok',
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
