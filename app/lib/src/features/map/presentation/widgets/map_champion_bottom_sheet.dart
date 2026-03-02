import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:flutter/material.dart';

class MapChampionBottomSheet extends StatelessWidget {
  const MapChampionBottomSheet({
    super.key,
    required this.selectedChampion,
    required this.champions,
    required this.onOpenProfile,
  });

  final MapChampionEntity selectedChampion;
  final List<MapChampionEntity> champions;
  final void Function(String userId) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final sorted = champions.toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));

    final leader = sorted.isNotEmpty ? sorted.first : selectedChampion;
    final others =
        sorted.length > 1 ? sorted.sublist(1) : const <MapChampionEntity>[];

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF171B21),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Regional Champion',
                    style: TextStyles.titleMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LeaderCard(
                champion: leader,
                onTap: () => onOpenProfile(leader.userId),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Rating',
                  style: TextStyles.titleMain.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: others.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      child: Text(
                        'No additional champions yet.',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      shrinkWrap: true,
                      itemCount: others.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = others[index];
                        return _RatingRow(
                          champion: item,
                          rank: index + 2,
                          onTap: () => onOpenProfile(item.userId),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({
    required this.champion,
    required this.onTap,
  });

  final MapChampionEntity champion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              champion.userId.isNotEmpty
                  ? champion.userId[0].toUpperCase()
                  : '?',
              style: TextStyles.titleMain.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            champion.userId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyMain.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Score: ${champion.score}',
            style: TextStyles.bodySecondary.copyWith(
              color: const Color(0xFFE8C547),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.champion,
    required this.rank,
    required this.onTap,
  });

  final MapChampionEntity champion;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$rank',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              child: Text(
                champion.userId.isNotEmpty
                    ? champion.userId[0].toUpperCase()
                    : '?',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                champion.userId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${champion.score}',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
