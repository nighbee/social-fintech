import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PublicUserActionButtons extends StatelessWidget {
  const PublicUserActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                // TODO: Add to favorites logic
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF656565)),
                ),
                child: Center(
                  child: Text(
                    'Added to favorites',
                    style: TextStyles.titleTag.copyWith(
                      color: Color(0xFFCACACA),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // TODO: Message user logic
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF656565)),
                ),
                child: Center(
                  child: Text(
                    'Message',
                    style: TextStyles.titleTag.copyWith(
                      color: Color(0xFFCACACA),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
