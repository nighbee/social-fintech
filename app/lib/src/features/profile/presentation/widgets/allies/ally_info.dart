part of '../../pages/allies_page.dart';


class _AllyInfo extends StatelessWidget {
  const _AllyInfo({required this.ally});

  final AllyProfileEntity ally;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ally.displayName,
          style: TextStyles.bodyMain.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(4),
        Row(
          children: [
            Text(
              ally.rankTier,
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFF5E8DFF),
              ),
            ),
            Text(
              ' · ',
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFF6D6D6D),
              ),
            ),
            Text(
              '${ally.reputationScore}',
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFFFFA500),
              ),
            ),
            const Gap(4),
            const Icon(Icons.star, size: 14, color: Color(0xFFFFA500)),
          ],
        ),
      ],
    );
  }
}
