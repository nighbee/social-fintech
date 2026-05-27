import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({super.key});

  static const Color _actionBtnFill = Color(0xFF303030);
  static const Color _primaryBtnBorder = Color.fromRGBO(101, 101, 101, 0.25);

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
        const Gap(6),
        Expanded(
          flex: 152,
          child: _PrimaryActionPill(
            label: 'Share profile',
            onTap: () {},
          ),
        ),
        const Gap(6),
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
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: ProfileActionButtons._actionBtnFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ProfileActionButtons._primaryBtnBorder,
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
            fontWeight: FontWeight.w400,
            height: 14 / 12,
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
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(10, 2, 9, 2),
        decoration: BoxDecoration(
          color: ProfileActionButtons._actionBtnFill,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color.fromRGBO(160, 160, 160, 0.2),
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
