part of '../../pages/allies_page.dart';


class _AllyCard extends StatelessWidget {
  const _AllyCard({required this.ally});

  final AllyProfileEntity ally;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _Avatar(imageUrl: ally.avatarUrl),
          const Gap(12),
          Expanded(child: _AllyInfo(ally: ally)),
        ],
      ),
    );
  }
}
