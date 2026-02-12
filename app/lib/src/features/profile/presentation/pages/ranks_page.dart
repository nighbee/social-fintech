import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/presentation/utils/mock_ranks_data.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/rank_card.dart';
import 'package:flutter/material.dart';

class RangsPage extends StatelessWidget {
  const RangsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: const CustomAppBar(title: 'Rang'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 16),
        child: PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: mockRanks.length,
          itemBuilder: (context, index) {
            final rank = mockRanks[index];
            final nextRank = index < mockRanks.length - 1
                ? mockRanks[index + 1]
                : null;

            return Center(
              child: RankCard(rank: rank, nextRank: nextRank),
            );
          },
        ),
      ),
    );
  }
}
