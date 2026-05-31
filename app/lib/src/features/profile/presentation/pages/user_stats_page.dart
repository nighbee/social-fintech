import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:app/src/features/profile/data/models/profile_stats_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
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
  ProfileStatsDto? _stats;
  String? _statsError;
  bool _isStatsLoading = false;

  UserStatsData get _baseData =>
      widget.isCurrentUser ? _currentUserStatsData : _publicUserStatsData;

  UserStatsData get _data {
    final stats = _stats;
    if (stats == null) {
      return _baseData
          ._withCurrentGoldHonor(widget.reputationScore)
          ._withRankParts(_rankParts);
    }
    return _baseData.withStats(stats)._withRankParts(_rankParts);
  }

  _RankParts get _rankParts => _RankParts.fromRankTier(widget.rankTier);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant UserStatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isCurrentUser != widget.isCurrentUser) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final userId = widget.userId?.trim() ?? '';
    if (!widget.isCurrentUser && userId.isEmpty) return;

    setState(() {
      _isStatsLoading = true;
      _statsError = null;
    });

    final remote = getIt<IProfileRemote>(instanceName: 'ProfileRemoteImpl');
    final result = widget.isCurrentUser
        ? await remote.getMyStats()
        : await remote.getPublicStats(UserIdRequest(userId: userId));

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isStatsLoading = false;
          _statsError = error.message;
        });
      },
      (stats) {
        setState(() {
          _isStatsLoading = false;
          _stats = stats;
        });
      },
    );
  }

  void _showMedalDialog(UserStatsMedalItem medal) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => medal.isUnlocked
          ? _EarnedMedalDialog(medal: medal)
          : _LockedMedalDialog(medal: medal),
    );
  }

  void _openAllMedals() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AllMedalsPage(
          medals: _data.medals,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        title: 'User Stats',
        backgroundColor: AppColors.colorff19191A,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Assets.icons.more.svg(
                width: 24,
                height: 24,
                color: AppColors.colorffffffff,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              _UserStatsMedalStrip(
                medals: _data.medals.take(4).toList(),
                onMedalTap: _showMedalDialog,
              ),
              if (_isStatsLoading || _statsError != null) ...[
                const Gap(14),
                _StatsLoadingNotice(
                  isLoading: _isStatsLoading,
                  error: _statsError,
                ),
              ],
              const Gap(25),
              for (final season in _data.seasons) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: season.isCurrent ? 0 : 12),
                  child: _SeasonStatsCard(
                    season: season,
                    onCountdownTap: season.isCurrent
                        ? () => _showSeasonCountdownDialog(season)
                        : null,
                    onPatronBadgeTap: (season.footerBadgeLabel ?? '').isNotEmpty
                        ? _showPatronBadgeDialog
                        : null,
                  ),
                ),
                if (season != _data.seasons.last) const Gap(20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSeasonCountdownDialog(UserStatsSeasonItem season) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (_) => _SeasonCountdownDialog(label: season.trailingLabel),
    );
  }

  void _showPatronBadgeDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (_) => const _PatronBadgeDialog(),
    );
  }
}

class _AllMedalsPage extends StatelessWidget {
  const _AllMedalsPage({
    required this.medals,
  });

  final List<UserStatsMedalItem> medals;

  void _showMedalDialog(BuildContext context, UserStatsMedalItem medal) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => medal.isUnlocked
          ? _EarnedMedalDialog(medal: medal)
          : _LockedMedalDialog(medal: medal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        title: 'Medals',
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: GridView.builder(
            itemCount: medals.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final medal = medals[index];
              return _MedalTile(
                medal: medal,
                onTap: () => _showMedalDialog(context, medal),
                tileWidth: double.infinity,
                artSize: 64,
                medalSize: 48,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatsLoadingNotice extends StatelessWidget {
  const _StatsLoadingNotice({
    required this.isLoading,
    required this.error,
  });

  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Text(
      isLoading ? 'Loading stats...' : 'Stats are temporarily unavailable',
      style: TextStyles.bodyMain.copyWith(
        fontSize: 13,
        height: 1.35,
        color: error == null
            ? AppColors.textBrand.withValues(alpha: 0.62)
            : Colors.redAccent.withValues(alpha: 0.82),
      ),
    );
  }
}

class _UserStatsMedalStrip extends StatelessWidget {
  const _UserStatsMedalStrip({
    required this.medals,
    required this.onMedalTap,
  });

  final List<UserStatsMedalItem> medals;
  final ValueChanged<UserStatsMedalItem> onMedalTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final medal in medals)
            _MedalTile(
              medal: medal,
              onTap: () => onMedalTap(medal),
            ),
        ],
      ),
    );
  }
}

class _MedalTile extends StatelessWidget {
  const _MedalTile({
    required this.medal,
    required this.onTap,
    this.tileWidth = 80,
    this.artSize = 80,
    this.medalSize = 56,
  });

  final UserStatsMedalItem medal;
  final VoidCallback onTap;
  final double tileWidth;
  final double artSize;
  final double medalSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tileWidth,
        child: Column(
          children: [
            Container(
              width: artSize,
              height: artSize,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: medal.isUnlocked
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: _MedalArt(
                  medal: medal,
                  size: medalSize,
                ),
              ),
            ),
            const Gap(8),
            Text(
              medal.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.bodyMain.copyWith(
                fontSize: 11,
                height: 1.35,
                color: medal.isUnlocked
                    ? AppColors.textBrand
                    : AppColors.textBrand.withValues(alpha: 0.52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonStatsCard extends StatelessWidget {
  const _SeasonStatsCard({
    required this.season,
    this.onCountdownTap,
    this.onPatronBadgeTap,
  });

  final UserStatsSeasonItem season;
  final VoidCallback? onCountdownTap;
  final VoidCallback? onPatronBadgeTap;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 6,
      blurSigma: 18,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      borderColor: season.isCurrent
          ? const Color(0xFFA7CCE4).withValues(alpha: 0.44)
          : Colors.white.withValues(alpha: 0.08),
      borderWidth: 1,
      enableWhiteGlow: false,
      dropShadowColor: season.isCurrent
          ? const Color(0xFFA7CCE4).withValues(alpha: 0.46)
          : Colors.black.withValues(alpha: 0.48),
      dropShadowBlurRadius: season.isCurrent ? 10 : 32,
      dropShadowOffset: const Offset(0, 4),
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
              season.isCurrent
                  ? _SeasonCountdownPill(
                      label: season.trailingLabel,
                      onTap: onCountdownTap,
                    )
                  : Text(
                      season.trailingLabel,
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        color: const Color(0xFFA3A3A3),
                      ),
                    ),
            ],
          ),
          const Gap(26),
          Column(
            children: [
              _SeasonGem(season: season),
              const Gap(12),
              Text(
                season.rankName,
                style: TextStyles.titleBig.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  color: const Color(0xFFD1E7FF),
                  letterSpacing: -0.48,
                ),
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    season.rankTier,
                    style: TextStyles.titleHeadline.copyWith(
                      fontSize: 20,
                      height: 1.1,
                      color: const Color(0xB3F1F6FD),
                    ),
                  ),
                  const Gap(5),
                  Container(
                    width: 2,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xB3F1F6FD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Gap(5),
                  Text(
                    season.rankGrade,
                    style: TextStyles.titleHeadline.copyWith(
                      fontSize: 20,
                      height: 1.1,
                      color: const Color(0xB3F1F6FD),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Gap(26),
          Row(
            children: [
              Expanded(
                child: _SeasonMetric(
                  label: 'Gained gold honor',
                  value: season.gainedGoldHonor,
                  iconColor: const Color(0xFFC8A66C),
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
                  value: season.givenSilverHonor,
                  iconColor: const Color(0xFFA8ACB7),
                ),
              ),
            ],
          ),
          if ((season.footerBadgeLabel ?? '').isNotEmpty) ...[
            const Gap(18),
            GestureDetector(
              onTap: onPatronBadgeTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  season.footerBadgeLabel!,
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: const Color(0xFFE5C367),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeasonCountdownPill extends StatelessWidget {
  const _SeasonCountdownPill({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyles.bodyLarge.copyWith(
                fontSize: 16,
                height: 1.4,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(6),
            const Icon(
              Icons.hourglass_bottom_rounded,
              size: 16,
              color: AppColors.textBrand,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonCountdownDialog extends StatelessWidget {
  const _SeasonCountdownDialog({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 22,
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 20),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        borderColor: Colors.white.withValues(alpha: 0.08),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.56),
        dropShadowBlurRadius: 34,
        dropShadowOffset: const Offset(0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 78,
              color: AppColors.textBrand,
            ),
            const Gap(18),
            Text(
              'Seasons ends in $label',
              textAlign: TextAlign.center,
              style: TextStyles.titleMain.copyWith(
                fontSize: 22,
                height: 1.12,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(14),
            Text(
              'After season end, your seasonal counters reset. Past seasons remain saved in Season History.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                height: 1.28,
                color: const Color(0xFFCACACA),
              ),
            ),
            const Gap(24),
            CustomOutlinedButton(
              text: 'Ok',
              onTap: () => Navigator.of(context).pop(),
              width: double.infinity,
              borderRadius: 6,
              borderColor: AppColors.textBrand,
              backgroundColor: Colors.transparent,
              textStyle: TextStyles.titleTag.copyWith(
                fontSize: 16,
                color: const Color(0xFFEAEAEA),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatronBadgeDialog extends StatelessWidget {
  const _PatronBadgeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 22,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        borderColor: Colors.white.withValues(alpha: 0.08),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.56),
        dropShadowBlurRadius: 34,
        dropShadowOffset: const Offset(0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(
                Icons.close_rounded,
                size: 24,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(24),
            Text(
              'The Patron Badge marks those who sustain a culture where Honor is earned and openly recognized.',
              textAlign: TextAlign.center,
              style: TextStyles.titleMain.copyWith(
                fontSize: 18,
                height: 1.18,
                color: AppColors.textBrand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonGem extends StatelessWidget {
  const _SeasonGem({required this.season});

  final UserStatsSeasonItem season;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.14),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipOval(
        child: season.gemImage.image(
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _SeasonMetric extends StatelessWidget {
  const _SeasonMetric({
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final String label;
  final int value;
  final Color iconColor;

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
              color: const Color(0xFF5F6880),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: TextStyles.titleHeadline.copyWith(
                  fontSize: 20,
                  height: 1.1,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(6),
              Assets.icons.silverCoin.svg(
                width: 25,
                height: 25,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MedalArt extends StatelessWidget {
  const _MedalArt({
    required this.medal,
    required this.size,
  });

  final UserStatsMedalItem medal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary =
        medal.isUnlocked ? medal.primaryColor : const Color(0xFF666769);
    final secondary =
        medal.isUnlocked ? medal.secondaryColor : const Color(0xFF2E2F31);

    final decoratedChild = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.2, -0.2),
          colors: [
            primary.withValues(alpha: 0.94),
            secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: medal.isUnlocked ? 0.22 : 0.10),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SizedBox(
        width: size,
        height: size,
      ),
    );

    return switch (medal.shape) {
      UserStatsMedalShape.circle => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: medal.isUnlocked ? 0.14 : 0.08),
            ),
          ),
          child: ClipOval(child: decoratedChild),
        ),
      UserStatsMedalShape.roundedSquare => Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: medal.isUnlocked ? 0.14 : 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: decoratedChild,
          ),
        ),
      UserStatsMedalShape.octagon => SizedBox(
          width: size,
          height: size,
          child: ClipPath(
            clipper: _OctagonClipper(),
            child: decoratedChild,
          ),
        ),
      UserStatsMedalShape.triangle => SizedBox(
          width: size,
          height: size,
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: decoratedChild,
          ),
        ),
    };
  }
}

class _EarnedMedalDialog extends StatelessWidget {
  const _EarnedMedalDialog({required this.medal});

  final UserStatsMedalItem medal;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 20,
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        borderColor: Colors.white.withValues(alpha: 0.08),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MedalArt(
              medal: medal,
              size: 120,
            ),
            const Gap(18),
            Text(
              medal.earnedOnLabel ?? 'Earned',
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                fontSize: 12,
                height: 1.35,
                color: const Color(0xFFA3A3A3),
              ),
            ),
            const Gap(10),
            Text(
              medal.title,
              textAlign: TextAlign.center,
              style: TextStyles.titleMain.copyWith(
                fontSize: 20,
                height: 1.1,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(12),
            Text(
              medal.unlockedDescription,
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: const Color(0xFFA3A3A3),
                height: 1.4,
              ),
            ),
            const Gap(24),
            CustomOutlinedButton(
              text: 'Ok',
              onTap: () => Navigator.of(context).pop(),
              width: double.infinity,
              borderRadius: 6,
              borderColor: AppColors.textBrand,
              backgroundColor: Colors.transparent,
              textStyle: TextStyles.titleTag.copyWith(
                fontSize: 16,
                color: const Color(0xFFEAEAEA),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedMedalDialog extends StatelessWidget {
  const _LockedMedalDialog({required this.medal});

  final UserStatsMedalItem medal;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 20,
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        borderColor: Colors.white.withValues(alpha: 0.08),
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MedalArt(
              medal: medal,
              size: 120,
            ),
            const Gap(20),
            Text(
              'Not earned yet',
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: const Color(0xFFA3A3A3),
                height: 1.4,
              ),
            ),
            const Gap(10),
            Text(
              medal.title,
              textAlign: TextAlign.center,
              style: TextStyles.titleMain.copyWith(
                fontSize: 20,
                height: 1.1,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(12),
            Text(
              medal.lockedDescription,
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: const Color(0xFFA3A3A3),
                height: 1.4,
              ),
            ),
            const Gap(24),
            CustomOutlinedButton(
              text: 'Ok',
              onTap: () => Navigator.of(context).pop(),
              width: double.infinity,
              borderRadius: 6,
              borderColor: AppColors.textBrand,
              backgroundColor: Colors.transparent,
              textStyle: TextStyles.titleTag.copyWith(
                fontSize: 16,
                color: const Color(0xFFEAEAEA),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final inset = size.width * 0.18;
    return Path()
      ..moveTo(inset, 0)
      ..lineTo(size.width - inset, 0)
      ..lineTo(size.width, inset)
      ..lineTo(size.width, size.height - inset)
      ..lineTo(size.width - inset, size.height)
      ..lineTo(inset, size.height)
      ..lineTo(0, size.height - inset)
      ..lineTo(0, inset)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

enum UserStatsMedalShape {
  circle,
  roundedSquare,
  octagon,
  triangle,
}

class UserStatsData {
  const UserStatsData({
    required this.medals,
    required this.seasons,
  });

  final List<UserStatsMedalItem> medals;
  final List<UserStatsSeasonItem> seasons;

  UserStatsData withStats(ProfileStatsDto stats) {
    if (seasons.isEmpty) return this;

    return UserStatsData(
      medals: medals,
      seasons: [
        seasons.first.copyWith(
          gainedGoldHonor: stats.totalReceivedSeals,
          givenSilverHonor: stats.totalSentSeals,
        ),
        ...seasons.skip(1),
      ],
    );
  }

  UserStatsData _withCurrentGoldHonor(int value) {
    if (value <= 0 || seasons.isEmpty) return this;

    return UserStatsData(
      medals: medals,
      seasons: [
        seasons.first.copyWith(gainedGoldHonor: value),
        ...seasons.skip(1),
      ],
    );
  }

  UserStatsData _withRankParts(_RankParts parts) {
    if (!parts.hasValue || seasons.isEmpty) return this;

    return UserStatsData(
      medals: medals,
      seasons: [
        for (final season in seasons)
          season.copyWith(
            rankName: season.isCurrent ? parts.name : season.rankName,
            rankTier: season.isCurrent ? parts.quality : season.rankTier,
            rankGrade: season.isCurrent ? parts.level : season.rankGrade,
          ),
      ],
    );
  }
}

class UserStatsMedalItem {
  const UserStatsMedalItem({
    required this.id,
    required this.title,
    required this.shape,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isUnlocked,
    required this.lockedDescription,
    required this.unlockedDescription,
    this.earnedOnLabel,
  });

  final String id;
  final String title;
  final UserStatsMedalShape shape;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isUnlocked;
  final String lockedDescription;
  final String unlockedDescription;
  final String? earnedOnLabel;
}

class UserStatsSeasonItem {
  const UserStatsSeasonItem({
    required this.title,
    required this.trailingLabel,
    required this.rankName,
    required this.rankTier,
    required this.rankGrade,
    required this.gainedGoldHonor,
    required this.givenSilverHonor,
    required this.gemImage,
    this.isCurrent = false,
    this.footerBadgeLabel,
  });

  final String title;
  final String trailingLabel;
  final String rankName;
  final String rankTier;
  final String rankGrade;
  final int gainedGoldHonor;
  final int givenSilverHonor;
  final AssetGenImage gemImage;
  final bool isCurrent;
  final String? footerBadgeLabel;

  UserStatsSeasonItem copyWith({
    String? title,
    String? trailingLabel,
    String? rankName,
    String? rankTier,
    String? rankGrade,
    int? gainedGoldHonor,
    int? givenSilverHonor,
    AssetGenImage? gemImage,
    bool? isCurrent,
    String? footerBadgeLabel,
  }) {
    return UserStatsSeasonItem(
      title: title ?? this.title,
      trailingLabel: trailingLabel ?? this.trailingLabel,
      rankName: rankName ?? this.rankName,
      rankTier: rankTier ?? this.rankTier,
      rankGrade: rankGrade ?? this.rankGrade,
      gainedGoldHonor: gainedGoldHonor ?? this.gainedGoldHonor,
      givenSilverHonor: givenSilverHonor ?? this.givenSilverHonor,
      gemImage: gemImage ?? this.gemImage,
      isCurrent: isCurrent ?? this.isCurrent,
      footerBadgeLabel: footerBadgeLabel ?? this.footerBadgeLabel,
    );
  }
}

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

  bool get hasValue =>
      name.isNotEmpty || quality.isNotEmpty || level.isNotEmpty;
}

final UserStatsData _currentUserStatsData = UserStatsData(
  medals: const [
    UserStatsMedalItem(
      id: 'founder',
      title: 'Founder medal',
      shape: UserStatsMedalShape.circle,
      primaryColor: Color(0xFF4B7E77),
      secondaryColor: Color(0xFF123A38),
      isUnlocked: true,
      lockedDescription:
          'Issued to the first 3000 members who laid the foundation.',
      unlockedDescription:
          'You are now one of the first 3000 founding members who laid the foundation. Thank you!',
      earnedOnLabel: 'Earned on Oct 15, 2023',
    ),
    UserStatsMedalItem(
      id: 'district-crown',
      title: 'District Crown',
      shape: UserStatsMedalShape.roundedSquare,
      primaryColor: Color(0xFFD2953A),
      secondaryColor: Color(0xFF6F4214),
      isUnlocked: true,
      lockedDescription:
          'Awarded to people who consistently stand out in their district.',
      unlockedDescription:
          'Your local impact is visible now. You have earned the District Crown.',
      earnedOnLabel: 'Earned this season',
    ),
    UserStatsMedalItem(
      id: 'clarity-master',
      title: 'Clarity Master',
      shape: UserStatsMedalShape.octagon,
      primaryColor: Color(0xFFA75363),
      secondaryColor: Color(0xFF562131),
      isUnlocked: true,
      lockedDescription:
          'Reserved for members whose recognition remains steady and clear.',
      unlockedDescription:
          'Your recognition pattern is consistent and respected. Clarity Master is now yours.',
      earnedOnLabel: 'Earned this season',
    ),
    UserStatsMedalItem(
      id: 'pillar-community',
      title: 'Pillar of the Community',
      shape: UserStatsMedalShape.triangle,
      primaryColor: Color(0xFF4A6ECF),
      secondaryColor: Color(0xFF162F72),
      isUnlocked: false,
      lockedDescription:
          'Issued to members whose support of others becomes a lasting community signal.',
      unlockedDescription:
          'You have become a pillar others rely on. The community now recognizes your impact.',
    ),
    UserStatsMedalItem(
      id: 'season-medal',
      title: 'Season medal',
      shape: UserStatsMedalShape.circle,
      primaryColor: Color(0xFF8E8E8E),
      secondaryColor: Color(0xFF3C3C3C),
      isUnlocked: false,
      lockedDescription:
          'Earned by finishing a season with a visible honor record.',
      unlockedDescription: 'Your season record is now preserved as a medal.',
    ),
    UserStatsMedalItem(
      id: 'jade-crown',
      title: 'Jade Crown',
      shape: UserStatsMedalShape.roundedSquare,
      primaryColor: Color(0xFFBDBDBD),
      secondaryColor: Color(0xFF5A5A5A),
      isUnlocked: false,
      lockedDescription:
          'Awarded for reaching a high local standing in a completed season.',
      unlockedDescription: 'Your local standing earned the Jade Crown.',
    ),
    UserStatsMedalItem(
      id: 'scarlet-master',
      title: 'Clarity Master',
      shape: UserStatsMedalShape.octagon,
      primaryColor: Color(0xFF8E8E8E),
      secondaryColor: Color(0xFF3C3C3C),
      isUnlocked: false,
      lockedDescription:
          'Reserved for members whose recognition remains steady and clear.',
      unlockedDescription:
          'Your recognition pattern is consistent and respected.',
    ),
    UserStatsMedalItem(
      id: 'community-pillar-alt',
      title: 'Pillar of the Community',
      shape: UserStatsMedalShape.triangle,
      primaryColor: Color(0xFF8E8E8E),
      secondaryColor: Color(0xFF3C3C3C),
      isUnlocked: false,
      lockedDescription:
          'Issued to members whose support of others becomes a lasting community signal.',
      unlockedDescription: 'You have become a pillar others rely on.',
    ),
  ],
  seasons: [
    UserStatsSeasonItem(
      title: 'Season 3',
      trailingLabel: '20 d',
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      gainedGoldHonor: 26,
      givenSilverHonor: 25,
      gemImage: Assets.images.moonstone,
      isCurrent: true,
    ),
    UserStatsSeasonItem(
      title: 'Season 2',
      trailingLabel: '1 MAY - 1 OCT',
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      gainedGoldHonor: 24,
      givenSilverHonor: 21,
      gemImage: Assets.images.pearl,
    ),
    UserStatsSeasonItem(
      title: 'Season 1',
      trailingLabel: '1 MAY - 1 OCT',
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      gainedGoldHonor: 18,
      givenSilverHonor: 14,
      gemImage: Assets.images.onyx,
    ),
  ],
);

final UserStatsData _publicUserStatsData = UserStatsData(
  medals: _currentUserStatsData.medals,
  seasons: [
    UserStatsSeasonItem(
      title: 'Season 3',
      trailingLabel: '20 d',
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      gainedGoldHonor: 26,
      givenSilverHonor: 25,
      gemImage: Assets.images.moonstone,
      isCurrent: true,
    ),
    UserStatsSeasonItem(
      title: 'Season 2',
      trailingLabel: '1 MAY - 1 OCT',
      rankName: 'Moonstone',
      rankTier: 'Intention',
      rankGrade: 'A',
      gainedGoldHonor: 21,
      givenSilverHonor: 17,
      gemImage: Assets.images.pearl,
    ),
  ],
);
