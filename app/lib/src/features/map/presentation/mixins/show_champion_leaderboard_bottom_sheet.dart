import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/map/domain/entities/map_champion_entity.dart';
import 'package:app/src/features/map/presentation/widgets/map_champion_bottom_sheet.dart';
import 'package:flutter/material.dart';

mixin ShowChampionLeaderboardBottomSheet {
  void showChampionLeaderboardBottomSheet(
    BuildContext context, {
    required MapChampionEntity selectedChampion,
    required List<MapChampionEntity> champions,
    required void Function(String userId) onOpenProfile,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020).withValues(alpha: 0.20),
        showDivider: false,
        child: MapChampionBottomSheet(
          selectedChampion: selectedChampion,
          champions: champions,
          onOpenProfile: (userId) {
            Navigator.of(context, rootNavigator: true).pop();
            onOpenProfile(userId);
          },
        ),
      ),
    );
  }
}
