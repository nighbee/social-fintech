import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/presentation/models/rank_card_item.dart';
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
  List<RankCardItem> _ranks = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadRanks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRanks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final client = getIt<RestClient>(instanceName: 'DioClient');
    final result = await client.get(EndPoints.ranks);
    if (!mounted) return;

    await result.fold(
      (error) {
        setState(() {
          _isLoading = false;
          _error = error.message;
        });
      },
      (response) async {
        try {
          final data = Map<String, dynamic>.from(response.data as Map);
          final rawRanks = data['ranks'] as List<dynamic>? ?? const [];
          final currentRank = await client.get(EndPoints.myRank);
          if (!mounted) return;

          Map<String, dynamic>? currentRankData;
          currentRank.fold(
            (_) {},
            (response) {
              currentRankData = Map<String, dynamic>.from(response.data as Map);
            },
          );
          final currentRankName =
              (currentRankData?['rank_name'] as String? ?? '').toLowerCase();
          final currentLevel =
              (currentRankData?['level'] as String? ?? '').toUpperCase();
          final currentRankOrder = rawRanks
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .where(
                (rank) =>
                    (rank['name'] as String? ?? '').toLowerCase() ==
                    currentRankName,
              )
              .map((rank) => (rank['order'] as num?)?.toInt() ?? 0)
              .firstOrNull;
          final ranks = rawRanks
              .map(
                (item) => _rankFromJson(
                  Map<String, dynamic>.from(item as Map),
                  currentRankOrder: currentRankOrder,
                  currentLevel: currentLevel,
                ),
              )
              .whereType<RankCardItem>()
              .toList(growable: false);

          setState(() {
            _isLoading = false;
            _ranks = ranks;
            _error = ranks.isEmpty ? 'Rank catalog is empty' : null;
            _currentPage = 0;
          });
        } catch (_) {
          setState(() {
            _isLoading = false;
            _error = 'Could not read the rank catalog';
          });
        }
      },
    );
  }

  RankCardItem? _rankFromJson(
    Map<String, dynamic> json, {
    required int? currentRankOrder,
    required String currentLevel,
  }) {
    final id = (json['id'] as String? ?? '').trim().toLowerCase();
    final visual = _rankVisuals[id];
    if (visual == null) return null;

    final description = (json['description'] as String? ?? '').trim();
    final sentenceEnd = description.indexOf('.');
    final headline = sentenceEnd >= 0
        ? description.substring(0, sentenceEnd + 1).trim()
        : description;
    final body = sentenceEnd >= 0
        ? description.substring(sentenceEnd + 1).trim()
        : description;
    final minSeals = (json['min_seals'] as num?)?.toInt() ?? 0;
    final maxSeals = (json['max_seals'] as num?)?.toInt();
    final isOpenEnded =
        id == 'supernova' || maxSeals == null || maxSeals >= 999999;
    final requiredHonorLabel = minSeals == 0
        ? '0-${(maxSeals ?? 1) - 1}'
        : isOpenEnded
            ? '$minSeals+'
            : '$minSeals-${maxSeals - 1}';
    final levels = (json['levels'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final rankOrder = (json['order'] as num?)?.toInt() ?? 0;
    final filledTierCount = switch (currentRankOrder) {
      null => 0,
      final current when rankOrder < current => levels.length,
      final current when rankOrder > current => 0,
      _ => currentLevel.isEmpty ? 0 : levels.indexOf(currentLevel) + 1,
    };

    return RankCardItem(
      name: (json['name'] as String? ?? id).trim(),
      tier: (json['quality'] as String? ?? '').trim(),
      headline: headline,
      description: body.isEmpty ? headline : body,
      requiredHonorLabel: requiredHonorLabel,
      image: visual.image,
      gemStyle: visual.style,
      filledTierCount: filledTierCount.clamp(0, levels.length),
      thresholdLabelAbove: minSeals == 0 ? null : '$minSeals',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: const CustomAppBar(title: 'Rang'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _loadRanks,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
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
                          itemCount: _ranks.length,
                          itemBuilder: (context, index) {
                            final rank = _ranks[index];
                            final nextRank = index < _ranks.length - 1
                                ? _ranks[index + 1]
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
                        children: List.generate(_ranks.length, (index) {
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

class _RankVisual {
  const _RankVisual(this.image, this.style);

  final AssetGenImage image;
  final RankGemStyle style;
}

final Map<String, _RankVisual> _rankVisuals = {
  'pearl': _RankVisual(Assets.images.pearl, RankGemStyle.pearl),
  'moonstone': _RankVisual(Assets.images.moonstone, RankGemStyle.moonstone),
  'jade': _RankVisual(Assets.images.jade, RankGemStyle.jade),
  'lapis': _RankVisual(Assets.images.lapislazuli, RankGemStyle.lapisLazuli),
  'ammolite': _RankVisual(Assets.images.ammolite, RankGemStyle.ammolite),
  'onyx': _RankVisual(Assets.images.onyx, RankGemStyle.onyx),
  'supernova': _RankVisual(Assets.images.supernova, RankGemStyle.supernova),
};
