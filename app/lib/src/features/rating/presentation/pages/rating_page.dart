import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/features/rating/presentation/bloc/rating_bloc.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final TextEditingController _searchController = TextEditingController();
  _RatingScope _selectedScope = _RatingScope.district;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_RatingEntry> _mapItemsToEntries(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final name = item['name']?.toString() ?? item['username']?.toString() ?? 'Unknown';
      final rank = (item['rank'] is int)
          ? item['rank'] as int
          : int.tryParse(item['rank']?.toString() ?? '') ?? 0;
      final honor = (item['honor'] is int)
          ? item['honor'] as int
          : int.tryParse(item['honor']?.toString() ?? '') ?? 0;
      final rankName = item['rank_name']?.toString() ?? item['rankName']?.toString() ?? '';
      final rankTier = item['rank_tier']?.toString() ?? item['rankTier']?.toString() ?? '';
      final rankGrade = item['rank_grade']?.toString() ?? item['rankGrade']?.toString() ?? '';
      final isCurrent = (item['is_current_user'] == true) || (item['isCurrentUser'] == true);

      return _RatingEntry(
        rank: rank,
        name: name,
        avatar: Assets.images.image,
        rankName: rankName,
        rankTier: rankTier,
        rankGrade: rankGrade,
        honorCount: honor,
        isCurrentUser: isCurrent,
      );
    }).toList();
  }

  List<_RatingEntry> _filterEntries(List<_RatingEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) => entry.matches(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.rating),
      body: SafeArea(
        bottom: false,
        child: BaseBlocWidget<RatingBloc, RatingEvent, RatingState>(
          bloc: getIt<RatingBloc>(),
          starterEvent: RatingEventLoad(),
          builder: (context, state, bloc) {
            List<_RatingEntry> entries = [];
            if (state is RatingStateLoaded) {
              entries = _mapItemsToEntries(state.items);
            }

            final filtered = _filterEntries(entries);
            final podium = filtered.where((e) => !e.isCurrentUser).take(3).toList();
            final ranked = filtered.where((e) => !e.isCurrentUser).skip(3).toList();
            _RatingEntry? current;
            for (final entry in filtered) {
              if (entry.isCurrentUser) {
                current = entry;
                break;
              }
            }

            final hasVisibleContent = podium.isNotEmpty || ranked.isNotEmpty || current != null;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: CustomTextField(
                    controller: _searchController,
                    labelText: 'Search',
                    hintText: 'Search',
                    onChanged: (_) => setState(() {}),
                    prefixIcon: Assets.icons.search.svg(
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        AppColors.colorffffffff,
                        BlendMode.srcIn,
                      ),
                    ),
                    showBorder: false,
                    showLabel: false,
                    backgroundColor: const Color(0xFF1E1E1E),
                    height: 48,
                    borderRadius: 10,
                    containerPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    contentPadding: EdgeInsets.zero,
                    textStyle: TextStyles.bodyLarge.copyWith(
                      color: AppColors.colorffE5E5E5,
                    ),
                    hintStyle: TextStyles.bodyLarge.copyWith(
                      color: const Color(0xFFBABABA),
                    ),
                  ),
                ),
                Expanded(
                  child: hasVisibleContent
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RatingPodium(entries: podium),
                              const Gap(26),
                              Text(
                                'Rating',
                                style: TextStyles.titleMain.copyWith(
                                  fontSize: 24,
                                  height: 26 / 24,
                                  color: AppColors.colorffffffff,
                                ),
                              ),
                              const Gap(12),
                              _RatingSegmentedControl(
                                selectedScope: _selectedScope,
                                onSelected: (scope) {
                                  setState(() {
                                    _selectedScope = scope;
                                  });
                                },
                              ),
                              const Gap(12),
                              if (ranked.isEmpty)
                                _EmptyListState(query: _searchController.text)
                              else
                                Column(
                                  children: [
                                    for (var i = 0; i < ranked.length; i++)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: i == ranked.length - 1 ? 0 : 10,
                                        ),
                                        child: _RatingListItem(
                                          entry: ranked[i],
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        )
                      : _EmptyResultsState(query: _searchController.text),
                ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                    child: _RatingListItem(
                      entry: current,
                      isPinned: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RatingPodium extends StatelessWidget {
  const _RatingPodium({required this.entries});

  final List<_RatingEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 344,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerEntry = entries.isNotEmpty ? entries[0] : null;
          final leftEntry = entries.length > 1 ? entries[1] : null;
          final rightEntry = entries.length > 2 ? entries[2] : null;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (centerEntry != null)
                Positioned(
                  top: 0,
                  left: (constraints.maxWidth - 164) / 2,
                  width: 164,
                  child: _RatingPodiumCard(
                    entry: centerEntry,
                    avatarSize: 100,
                    cardHeight: 196,
                  ),
                ),
              if (leftEntry != null)
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: 164,
                  child: _RatingPodiumCard(
                    entry: leftEntry,
                    avatarSize: 84,
                    cardHeight: 178,
                  ),
                ),
              if (rightEntry != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 164,
                  child: _RatingPodiumCard(
                    entry: rightEntry,
                    avatarSize: 84,
                    cardHeight: 178,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RatingPodiumCard extends StatelessWidget {
  const _RatingPodiumCard({
    required this.entry,
    required this.avatarSize,
    required this.cardHeight,
  });

  final _RatingEntry entry;
  final double avatarSize;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: Column(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFC98A28),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC98A28).withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: entry.avatar.image(fit: BoxFit.cover),
            ),
          ),
          const Gap(8),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyles.bodyMain.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 19 / 16,
              color: AppColors.colorffE5E5E5,
            ),
          ),
          const Gap(2),
          _RankMetaLine(
            entry: entry,
            centered: true,
            compact: true,
          ),
          const Gap(10),
          _HonorChip(count: entry.honorCount),
        ],
      ),
    );
  }
}

class _RatingSegmentedControl extends StatelessWidget {
  const _RatingSegmentedControl({
    required this.selectedScope,
    required this.onSelected,
  });

  final _RatingScope selectedScope;
  final ValueChanged<_RatingScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final scope in _RatingScope.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(scope),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedScope == scope
                        ? const Color(0xFF303030)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    scope.label,
                    style: TextStyles.bodyMain.copyWith(
                      fontSize: 12,
                      fontWeight: selectedScope == scope
                          ? FontWeight.w500
                          : FontWeight.w400,
                      height: 20 / 12,
                      color: selectedScope == scope
                          ? AppColors.colorffE5E5E5
                          : const Color(0xFF838383),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingListItem extends StatelessWidget {
  const _RatingListItem({
    required this.entry,
    this.isPinned = false,
  });

  final _RatingEntry entry;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPinned ? const Color(0xFF3B3B3B) : const Color(0xFF2A2A2A),
          width: 1,
        ),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, -1),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyles.titleBig.copyWith(
                fontSize: entry.rank >= 10 ? 30 : 32,
                fontWeight: FontWeight.w500,
                height: 1,
                color: AppColors.colorffffffff,
              ),
            ),
          ),
          const Gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: entry.avatar.image(
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 18 / 15,
                    color: AppColors.colorffE5E5E5,
                  ),
                ),
                const Gap(1),
                _RankMetaLine(entry: entry),
              ],
            ),
          ),
          const Gap(10),
          _HonorChip(
            count: entry.honorCount,
            dense: true,
          ),
        ],
      ),
    );
  }
}

class _RankMetaLine extends StatelessWidget {
  const _RankMetaLine({
    required this.entry,
    this.centered = false,
    this.compact = false,
  });

  final _RatingEntry entry;
  final bool centered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyles.bodyMain.copyWith(
      fontSize: compact ? 10 : 11,
      height: compact ? 12 / 10 : 13 / 11,
      color: const Color(0xFF74AFE3),
    );

    final iconSize = compact ? 10.0 : 12.0;

    return Wrap(
      alignment: centered ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: compact ? 4 : 5,
      runSpacing: 2,
      children: [
        Text(entry.rankName, style: textStyle),
        _MetaDot(size: compact ? 2 : 2.5),
        Text(entry.rankTier, style: textStyle),
        _MetaDot(size: compact ? 2 : 2.5),
        Text(entry.rankGrade, style: textStyle),
        Assets.icons.global.svg(
          width: iconSize,
          height: iconSize,
          colorFilter: const ColorFilter.mode(
            Color(0xFF74AFE3),
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF74AFE3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HonorChip extends StatelessWidget {
  const _HonorChip({
    required this.count,
    this.dense = false,
  });

  final int count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3533),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF4B4643),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.icons.silverCoin.svg(
            width: dense ? 16 : 18,
            height: dense ? 16 : 18,
          ),
          const Gap(6),
          Text(
            '$count',
            style: TextStyles.bodyMain.copyWith(
              fontSize: dense ? 14 : 15,
              fontWeight: FontWeight.w500,
              height: 18 / 14,
              color: AppColors.colorffE5E5E5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyResultsState extends StatelessWidget {
  const _EmptyResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Assets.icons.noPeople.svg(
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(
                AppColors.colorff838383,
                BlendMode.srcIn,
              ),
            ),
            const Gap(18),
            Text(
              query.trim().isEmpty
                  ? 'No rating entries yet.'
                  : 'No results for "${query.trim()}".',
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.colorffE5E5E5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyListState extends StatelessWidget {
  const _EmptyListState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Text(
        query.trim().isEmpty
            ? 'More ranked users will appear here as activity grows.'
            : 'No additional ranked users match your search.',
        style: TextStyles.bodyMain.copyWith(
          fontSize: 12,
          height: 15 / 12,
          color: const Color(0xFFA3A3A3),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

enum _RatingScope {
  district('District'),
  city('City'),
  country('Country');

  const _RatingScope(this.label);
  final String label;
}

class _RatingEntry {
  const _RatingEntry({
    required this.rank,
    required this.name,
    required this.avatar,
    required this.rankName,
    required this.rankTier,
    required this.rankGrade,
    required this.honorCount,
    this.isCurrentUser = false,
  });

  final int rank;
  final String name;
  final AssetGenImage avatar;
  final String rankName;
  final String rankTier;
  final String rankGrade;
  final int honorCount;
  final bool isCurrentUser;

  bool matches(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    final haystack =
        '$name $rankName $rankTier $rankGrade $rank $honorCount'.toLowerCase();
    return haystack.contains(normalizedQuery);
  }
}
