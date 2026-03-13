import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SilverBalanceChip extends StatelessWidget {
  const SilverBalanceChip({
    required this.count,
    super.key,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.colorff3F3F40, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.icons.silverCoin.svg(width: 24, height: 24),
          const Gap(4),
          Text(
            count.toString(),
            style: TextStyles.titleTag.copyWith(
              color: AppColors.colorffE5E5E5,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
