import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/presentation/utils/mock_ranks_data.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/rank_card.dart';
import 'package:flutter/material.dart';

class RangsPage extends StatefulWidget {
  const RangsPage({super.key});

  @override
  State<RangsPage> createState() => _RangsPageState();
}

class _RangsPageState extends State<RangsPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: const CustomAppBar(title: 'Rang'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
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
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(mockRanks.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: isActive ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.24),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
