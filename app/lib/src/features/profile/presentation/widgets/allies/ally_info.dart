part of '../../pages/allies_page.dart';

class _AllyInfo extends StatelessWidget {
  const _AllyInfo({required this.ally});

  final AllyProfileEntity ally;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          ally.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.bodyLarge.copyWith(
            color: AppColors.colorffE5E5E5,
            fontWeight: FontWeight.w600,
            height: 19.2 / 16,
          ),
        ),
        const Gap(3),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            if (ally.rankTier.trim().isNotEmpty)
              Text(
                ally.rankTier,
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 12,
                  height: 14 / 12,
                  color: const Color(0xFF74AFE3),
                ),
              ),
            if (ally.rankTier.trim().isNotEmpty) const _MetaDot(),
            Text(
              ally.reputationScore.toString(),
              style: TextStyles.bodyMain.copyWith(
                fontSize: 12,
                height: 14 / 12,
                color: const Color(0xFF74AFE3),
              ),
            ),
            const _MetaDot(),
            const Icon(
              Icons.public,
              size: 14,
              color: Color(0xFF74AFE3),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: Color(0xFF74AFE3),
        shape: BoxShape.circle,
      ),
    );
  }
}
