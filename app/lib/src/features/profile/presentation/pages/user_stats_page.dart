import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/data/models/profile_season_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class UserStatsPage extends StatefulWidget {
  const UserStatsPage({
    super.key,
    this.userId,
    this.isCurrentUser = true,
    this.rankTier = '',
    this.reputationScore = 0,
  });

  final String? userId;
  final bool isCurrentUser;
  final String rankTier;
  final int reputationScore;

  @override
  State<UserStatsPage> createState() => _UserStatsPageState();
}

class _UserStatsPageState extends State<UserStatsPage> {
  CurrentSeasonDto? _currentSeason;
  List<SeasonArchiveDto> _archive = const [];
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserStatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isCurrentUser != widget.isCurrentUser ||
        oldWidget.rankTier != widget.rankTier ||
        oldWidget.reputationScore != widget.reputationScore) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final remote = getIt<IProfileRemote>(instanceName: 'ProfileRemoteImpl');
    final currentResult = await remote.getCurrentSeason();
    final archiveResult = await remote.getSeasonArchive(
      userId: widget.isCurrentUser ? null : widget.userId,
    );

    if (!mounted) return;

    String? error;
    CurrentSeasonDto? current;
    List<SeasonArchiveDto> archive = const [];

    currentResult.fold(
      (failure) => error = failure.message,
      (value) => current = value,
    );
    archiveResult.fold(
      (failure) => error ??= failure.message,
      (value) => archive = value,
    );

    setState(() {
      _currentSeason = current;
      _archive = archive;
      _error = error;
      _isLoading = false;
    });
  }

  List<_SeasonViewData> get _seasons {
    final items = <_SeasonViewData>[];
    final current = _currentSeason;
    final rank = _RankParts.fromRankTier(widget.rankTier);

    if (current != null) {
      items.add(
        _SeasonViewData(
          title: _seasonTitle(current.year, current.half),
          trailingLabel: _remainingDays(current.secondsRemaining),
          rankName: rank.name,
          rankQuality: rank.quality,
          rankLevel: rank.level,
          receivedGold: widget.reputationScore,
          givenSilver: null,
          startsAt: current.startsAt,
          endsAt: current.endsAt,
          isCurrent: true,
        ),
      );
    }

    items.addAll(
      _archive.map(
        (item) => _SeasonViewData(
          title: _seasonTitle(item.year, item.half),
          trailingLabel: _dateRange(item.startsAt, item.endsAt),
          rankName: item.rankName,
          rankQuality: item.rankQuality,
          rankLevel: item.rankLevel,
          receivedGold: item.receivedSeals,
          givenSilver: item.givenSeals,
          startsAt: item.startsAt,
          endsAt: item.endsAt,
        ),
      ),
    );
    return items;
  }

  void _openAllMedals() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _AllMedalsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasons = _seasons;
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'User Stats',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _openAllMedals,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'View All Medals',
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textBrand,
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(12),
              const _MedalGrid(
                medals: _medalCatalogPreview,
                crossAxisCount: 4,
              ),
              const Gap(25),
              if (_isLoading)
                const _StatusMessage(label: 'Loading statistics...')
              else if (seasons.isEmpty)
                _StatusMessage(
                  label: _error == null
                      ? 'No season statistics yet'
                      : 'Statistics are temporarily unavailable',
                  onRetry: _error == null ? null : _load,
                )
              else ...[
                if (_error != null) ...[
                  _StatusMessage(
                    label: 'Some statistics could not be loaded',
                    onRetry: _load,
                  ),
                  const Gap(16),
                ],
                for (var index = 0; index < seasons.length; index++) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: seasons[index].isCurrent ? 0 : 12,
                    ),
                    child: _SeasonStatsCard(season: seasons[index]),
                  ),
                  if (index != seasons.length - 1) const Gap(20),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllMedalsPage extends StatelessWidget {
  const _AllMedalsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        title: 'Medals',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: _MedalGrid(
            medals: _medalCatalog,
            crossAxisCount: 4,
          ),
        ),
      ),
    );
  }
}

class _MedalGrid extends StatelessWidget {
  const _MedalGrid({
    required this.medals,
    required this.crossAxisCount,
  });

  final List<_MedalCatalogItem> medals;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(6),
      ),
      child: GridView.builder(
        itemCount: medals.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, index) => _LockedMedalTile(
          medal: medals[index],
        ),
      ),
    );
  }
}

class _LockedMedalTile extends StatelessWidget {
  const _LockedMedalTile({required this.medal});

  final _MedalCatalogItem medal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.24),
              ),
            ),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                0.48,
                0,
              ]),
              child: Image.asset(
                medal.assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        const Gap(6),
        Text(
          medal.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyles.bodyMain.copyWith(
            fontSize: 11,
            height: 1.15,
            color: const Color(0xFF777779),
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.label, this.onRetry});

  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const Gap(12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeasonStatsCard extends StatelessWidget {
  const _SeasonStatsCard({required this.season});

  final _SeasonViewData season;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: season.isCurrent
            ? const RadialGradient(
                center: Alignment(0.82, -0.9),
                radius: 1.45,
                colors: [
                  Color(0xFF29343B),
                  Color(0xFF1D2327),
                  Color(0xFF17191B),
                ],
                stops: [0, 0.48, 1],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E2124), Color(0xFF171819)],
              ),
        border: Border.all(
          color: season.isCurrent
              ? const Color(0xFF7695A8).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: season.isCurrent
                ? const Color(0xFF80B9DA).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.36),
            blurRadius: season.isCurrent ? 10 : 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  season.title,
                  style: TextStyles.titleBig.copyWith(
                    fontSize: 24,
                    height: 26 / 24,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
              _TrailingLabel(
                label: season.trailingLabel,
                isCurrent: season.isCurrent,
              ),
            ],
          ),
          const Gap(26),
          _RankBlock(season: season),
          const Gap(26),
          Row(
            children: [
              Expanded(
                child: _SeasonMetric(
                  label: 'Gained gold honor',
                  value: season.receivedGold,
                  isGold: true,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _SeasonMetric(
                  label: 'Given silver honor',
                  value: season.givenSilver,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrailingLabel extends StatelessWidget {
  const _TrailingLabel({required this.label, required this.isCurrent});

  final String label;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: isCurrent
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
          : EdgeInsets.zero,
      decoration: isCurrent
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            )
          : null,
      child: Text(
        label,
        style: TextStyles.bodyMain.copyWith(
          fontSize: 14,
          height: 1.4,
          color: const Color(0xFFA3A3A3),
        ),
      ),
    );
  }
}

class _RankBlock extends StatelessWidget {
  const _RankBlock({required this.season});

  final _SeasonViewData season;

  @override
  Widget build(BuildContext context) {
    final hasRank = season.rankName.isNotEmpty;
    return Column(
      children: [
        if (hasRank)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.14),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ClipOval(
              child: _rankGemImage(season.rankName).image(fit: BoxFit.cover),
            ),
          ),
        const Gap(12),
        Text(
          hasRank ? season.rankName : 'Rank unavailable',
          style: TextStyles.titleBig.copyWith(
            fontSize: 24,
            height: 1.2,
            color: hasRank ? const Color(0xFFD1E7FF) : AppColors.textSecondary,
          ),
        ),
        if (season.rankQuality.isNotEmpty || season.rankLevel.isNotEmpty) ...[
          const Gap(4),
          Text(
            [season.rankQuality, season.rankLevel]
                .where((part) => part.isNotEmpty)
                .join(' · '),
            style: TextStyles.titleHeadline.copyWith(
              fontSize: 20,
              height: 1.1,
              color: const Color(0xB3F1F6FD),
            ),
          ),
        ],
      ],
    );
  }
}

class _SeasonMetric extends StatelessWidget {
  const _SeasonMetric({
    required this.label,
    required this.value,
    this.isGold = false,
  });

  final String label;
  final int? value;
  final bool isGold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyles.bodyMain.copyWith(
              fontSize: 14,
              height: 1.4,
              color: const Color(0xFF8290AD),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value?.toString() ?? '—',
                style: TextStyles.titleHeadline.copyWith(
                  fontSize: 20,
                  height: 1.1,
                  color: AppColors.textBrand,
                ),
              ),
              if (value != null) ...[
                const Gap(6),
                if (isGold)
                  Image.asset(
                    'assets/images/golden_honor.png',
                    width: 25,
                    height: 25,
                  )
                else
                  Assets.icons.silverCoin.svg(width: 25, height: 25),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonViewData {
  const _SeasonViewData({
    required this.title,
    required this.trailingLabel,
    required this.rankName,
    required this.rankQuality,
    required this.rankLevel,
    required this.receivedGold,
    required this.givenSilver,
    required this.startsAt,
    required this.endsAt,
    this.isCurrent = false,
  });

  final String title;
  final String trailingLabel;
  final String rankName;
  final String rankQuality;
  final String rankLevel;
  final int receivedGold;
  final int? givenSilver;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isCurrent;
}

class _MedalCatalogItem {
  const _MedalCatalogItem({
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;
}

const _founderMedal = _MedalCatalogItem(
  title: 'Founder medal',
  assetPath: 'assets/images/Emerald_medal.png',
);
const _districtCrownMedal = _MedalCatalogItem(
  title: 'District Crown',
  assetPath: 'assets/images/Medal.png',
);
const _clarityMasterMedal = _MedalCatalogItem(
  title: 'Clarity Master',
  assetPath: 'assets/images/Rubin_medal.png',
);
const _pillarCommunityMedal = _MedalCatalogItem(
  title: 'Pillar of the Community',
  assetPath: 'assets/images/Topaz_medal.png',
);

const List<_MedalCatalogItem> _medalCatalogPreview = [
  _founderMedal,
  _districtCrownMedal,
  _clarityMasterMedal,
  _pillarCommunityMedal,
];

const List<_MedalCatalogItem> _medalCatalog = [
  ..._medalCatalogPreview,
  _founderMedal,
  _districtCrownMedal,
  _clarityMasterMedal,
  _pillarCommunityMedal,
];

class _RankParts {
  const _RankParts({
    required this.name,
    required this.quality,
    required this.level,
  });

  factory _RankParts.fromRankTier(String rankTier) {
    final parts = rankTier
        .split(RegExp(r'\s*[|•·]\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return _RankParts(
      name: parts.isNotEmpty ? parts[0] : '',
      quality: parts.length > 1 ? parts[1] : '',
      level: parts.length > 2 ? parts[2] : '',
    );
  }

  final String name;
  final String quality;
  final String level;
}

AssetGenImage _rankGemImage(String rankName) {
  return switch (rankName.trim().toLowerCase()) {
    'pearl' => Assets.images.pearl,
    'moonstone' => Assets.images.moonstone,
    'jade' => Assets.images.jade,
    'lapis lazuli' || 'lapis' => Assets.images.lapislazuli,
    'ammolite' => Assets.images.ammolite,
    'onyx' => Assets.images.onyx,
    'supernova' => Assets.images.supernova,
    _ => Assets.images.pearl,
  };
}

String _seasonTitle(int year, int half) {
  if (year <= 0 || half <= 0) return 'Season';
  return 'Season $half · $year';
}

String _remainingDays(int seconds) {
  if (seconds <= 0) return '0 d';
  return '${(seconds / Duration.secondsPerDay).ceil()} d';
}

String _dateRange(DateTime? startsAt, DateTime? endsAt) {
  if (startsAt == null || endsAt == null) return '';
  return '${_date(startsAt)} - ${_date(endsAt)}';
}

String _date(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${value.day} ${months[value.month - 1]}';
}
