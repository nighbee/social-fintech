import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/presentation/services/map_avatar_resolver_service.dart';
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
    final sortedOthers = champions
        .where((champion) => champion.h3Index != selectedChampion.h3Index)
        .toList(growable: false)
      ..sort((a, b) => b.score.compareTo(a.score));
    final leader = selectedChampion;

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
                    _titleForResolution(leader.resolution),
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
              child: sortedOthers.isEmpty
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
                      itemCount: sortedOthers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = sortedOthers[index];
                        return _RatingRow(
                          champion: item,
                          rank: index + 1,
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

  String _titleForResolution(int resolution) {
    switch (resolution) {
      case 5:
        return 'District Champion';
      case 4:
        return 'City Champion';
      case 2:
        return 'Country Champion';
      default:
        return 'Regional Champion';
    }
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
            child: _ChampionAvatar(
              champion: champion,
              radius: 36,
              labelStyle: TextStyles.titleMain.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _displayName(champion),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyMain.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_resolutionLabel(champion.resolution)} | ${champion.score} pts',
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
              child: _ChampionAvatar(
                champion: champion,
                radius: 18,
                labelStyle: TextStyles.bodyMain.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _displayName(champion),
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

class _ChampionAvatar extends StatelessWidget {
  const _ChampionAvatar({
    required this.champion,
    required this.radius,
    required this.labelStyle,
  });

  final MapChampionEntity champion;
  final double radius;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: MapAvatarResolverService.instance.resolveAvatar(
        fallbackUrl: champion.avatarUrl,
        userId: champion.userId,
        username: champion.username,
      ),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data?.trim() ?? '';
        if (resolvedUrl.isNotEmpty) {
          return CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(resolvedUrl),
            backgroundColor: Colors.transparent,
          );
        }
        return Text(_avatarLabel(champion), style: labelStyle);
      },
    );
  }
}

String _displayName(MapChampionEntity champion) {
  final username = champion.username.trim();
  if (username.isNotEmpty) {
    return username;
  }

  final userId = champion.userId;
  final trimmed = userId.trim();
  if (trimmed.isEmpty) {
    return 'Unknown champion';
  }
  if (trimmed.length <= 18) {
    return trimmed;
  }
  return '${trimmed.substring(0, 8)}...${trimmed.substring(trimmed.length - 4)}';
}

String _avatarLabel(MapChampionEntity champion) {
  final source = champion.username.trim().isNotEmpty
      ? champion.username
      : champion.userId;
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed[0].toUpperCase();
}

String _resolutionLabel(int resolution) {
  switch (resolution) {
    case 5:
      return 'District';
    case 4:
      return 'City';
    case 2:
      return 'Country';
    default:
      return 'Region';
  }
}
