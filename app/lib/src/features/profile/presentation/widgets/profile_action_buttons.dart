import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.pushNamed(
                  RouteNames.editProfile,
                ); // Safer to use named route if possible, or '/profile/edit'
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF656565)),
                ),
                child: Center(
                  child: Text(
                    'Edit profile',
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
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF656565)),
                ),
                child: Center(
                  child: Text(
                    'Share profile',
                    style: TextStyles.titleTag.copyWith(
                      color: Color(0xFFCACACA),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Gap(12),
          // Add Friend / User Icon Button
          GestureDetector(
            onTap: () {
              context.push('/profile/allies');
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF656565)),
              ),
              child: Center(
                child: Assets.icons.personFavourites.svg(
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Color(0xFFCACACA),
                    BlendMode.srcIn,
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
