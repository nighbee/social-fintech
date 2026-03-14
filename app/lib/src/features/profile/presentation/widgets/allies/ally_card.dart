part of '../../pages/allies_page.dart';

class _AllyCard extends StatelessWidget {
  const _AllyCard({required this.ally});

  final AllyProfileEntity ally;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0x1C214896),
            Color(0x1420325A),
            Color(0x101C1F27),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.pushNamed(
            RouteNames.publicProfile,
            pathParameters: {'userId': ally.userId},
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Avatar(imageUrl: ally.avatarUrl),
                const Gap(12),
                Expanded(child: _AllyInfo(ally: ally)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
