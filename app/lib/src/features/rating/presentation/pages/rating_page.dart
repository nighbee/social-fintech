import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
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

  List<_RatingEntry> get _entries =>
      _ratingEntriesByScope[_selectedScope] ?? const <_RatingEntry>[];

  List<_RatingEntry> get _filteredEntries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    return _entries.where((entry) => entry.matches(query)).toList();
  }

  List<_RatingEntry> get _podiumEntries => _filteredEntries
      .where((entry) => !entry.isCurrentUser)
      .take(3)
      .toList();

  List<_RatingEntry> get _rankedEntries => _filteredEntries
      .where((entry) => !entry.isCurrentUser)
      .skip(3)
      .toList();

  _RatingEntry? get _currentUserEntry {
    for (final entry in _filteredEntries) {
      if (entry.isCurrentUser) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasVisibleContent =
        _podiumEntries.isNotEmpty ||
        _rankedEntries.isNotEmpty ||
        _currentUserEntry != null;

    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.rating),
      body: SafeArea(
        bottom: false,
        child: Column(
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
                          _RatingPodium(entries: _podiumEntries),
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
                          if (_rankedEntries.isEmpty)
                            _EmptyListState(query: _searchController.text)
                          else
                            Column(
                              children: [
                                for (var i = 0; i < _rankedEntries.length; i++)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          i == _rankedEntries.length - 1
                                              ? 0
                                              : 10,
                                    ),
                                    child: _RatingListItem(
                                      entry: _rankedEntries[i],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    )
                  : _EmptyResultsState(query: _searchController.text),
            ),
            if (_currentUserEntry != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                child: _RatingListItem(
                  entry: _currentUserEntry!,
                  isPinned: true,
                ),
              ),
          ],
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
          final centerEntry = entries.length > 0 ? entries[0] : null;
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
                  color: const Color(0xFFC98A28).withOpacity(0.14),
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
                  color: Colors.black.withOpacity(0.22),
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

final Map<_RatingScope, List<_RatingEntry>> _ratingEntriesByScope = {
  _RatingScope.district: [
    _RatingEntry(
      rank: 1,
      name: 'Zhandos Berik',
      avatar: Assets.images.image,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 950,
    ),
    _RatingEntry(
      rank: 2,
      name: 'Auelkhanova Amina',
      avatar: Assets.images.jade,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 900,
    ),
    _RatingEntry(
      rank: 3,
      name: 'Zhannsa Berik',
      avatar: Assets.images.lapislazuli,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 800,
    ),
    _RatingEntry(
      rank: 4,
      name: 'Kundyz Akzhan',
      avatar: Assets.images.moonstone,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 75,
    ),
    _RatingEntry(
      rank: 5,
      name: 'Kundyz Akzhan',
      avatar: Assets.images.pearl,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 29,
    ),
    _RatingEntry(
      rank: 10,
      name: 'Kundyz Akzhan',
      avatar: Assets.images.onyx,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 26,
      isCurrentUser: true,
    ),
  ],
  _RatingScope.city: [
    _RatingEntry(
      rank: 1,
      name: 'Dana Mukan',
      avatar: Assets.images.supernova,
      rankName: 'Jade',
      rankTier: 'Integrity',
      rankGrade: 'S',
      honorCount: 1260,
    ),
    _RatingEntry(
      rank: 2,
      name: 'Arman Tulegen',
      avatar: Assets.images.image,
      rankName: 'Moonstone',
      rankTier: 'Clarity',
      rankGrade: 'A',
      honorCount: 1100,
    ),
    _RatingEntry(
      rank: 3,
      name: 'Saniya Omar',
      avatar: Assets.images.ammolite,
      rankName: 'Jade',
      rankTier: 'Integrity',
      rankGrade: 'A',
      honorCount: 980,
    ),
    _RatingEntry(
      rank: 4,
      name: 'Ilyas Kairat',
      avatar: Assets.images.jade,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'B',
      honorCount: 220,
    ),
    _RatingEntry(
      rank: 7,
      name: 'Madi Sarsen',
      avatar: Assets.images.lapislazuli,
      rankName: 'Moonstone',
      rankTier: 'Clarity',
      rankGrade: 'A',
      honorCount: 180,
    ),
    _RatingEntry(
      rank: 11,
      name: 'You',
      avatar: Assets.images.moonstone,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 54,
      isCurrentUser: true,
    ),
  ],
  _RatingScope.country: [
    _RatingEntry(
      rank: 1,
      name: 'Aruzhan S.',
      avatar: Assets.images.onyx,
      rankName: 'Onyx',
      rankTier: 'Resilience',
      rankGrade: 'S',
      honorCount: 2400,
    ),
    _RatingEntry(
      rank: 2,
      name: 'Timur B.',
      avatar: Assets.images.supernova,
      rankName: 'Sunstone',
      rankTier: 'Radiance',
      rankGrade: 'A',
      honorCount: 2110,
    ),
    _RatingEntry(
      rank: 3,
      name: 'Assel N.',
      avatar: Assets.images.ammolite,
      rankName: 'Ammolite',
      rankTier: 'Fortitude',
      rankGrade: 'A',
      honorCount: 1890,
    ),
    _RatingEntry(
      rank: 6,
      name: 'Zhanel R.',
      avatar: Assets.images.image,
      rankName: 'Jade',
      rankTier: 'Integrity',
      rankGrade: 'A',
      honorCount: 460,
    ),
    _RatingEntry(
      rank: 8,
      name: 'Dias A.',
      avatar: Assets.images.pearl,
      rankName: 'Moonstone',
      rankTier: 'Clarity',
      rankGrade: 'B',
      honorCount: 405,
    ),
    _RatingEntry(
      rank: 19,
      name: 'You',
      avatar: Assets.images.moonstone,
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      honorCount: 102,
      isCurrentUser: true,
    ),
  ],
};
