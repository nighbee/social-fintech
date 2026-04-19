import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({super.key});

  static const Color _primaryBtnFill = Color(0xFF6D6D6D);
  static const Color _primaryBtnBorder = Color(0xFF656565);
  static const Color _iconBtnFill = Color(0xFF404040);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 152,
          child: _PrimaryActionPill(
            label: 'Edit profile',
            onTap: () => context.pushNamed(RouteNames.editProfile),
          ),
        ),
        const Gap(4),
        Expanded(
          flex: 152,
          child: _PrimaryActionPill(
            label: 'Share profile',
            onTap: () {},
          ),
        ),
        const Gap(4),
        _IconActionPill(
          onTap: () => context.push('/profile/allies'),
        ),
      ],
    );
  }
}

class _PrimaryActionPill extends StatelessWidget {
  const _PrimaryActionPill({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ProfileActionButtons._primaryBtnFill.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ProfileActionButtons._primaryBtnBorder.withValues(
              alpha: 0.25,
            ),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyles.titleTag.copyWith(
            color: const Color(0xFFCACACA),
            fontSize: 12,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _IconActionPill extends StatelessWidget {
  const _IconActionPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 43,
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(10, 2, 9, 2),
        decoration: BoxDecoration(
          color: ProfileActionButtons._iconBtnFill.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Assets.icons.personFavourites.svg(
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(
            Color(0xFFCACACA),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
