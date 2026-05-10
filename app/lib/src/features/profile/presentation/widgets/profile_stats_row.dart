import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    required this.goldenSeals,
    this.statsLabel = 'Your Stats',
    super.key,
  });

  final int goldenSeals;
  final String statsLabel;

  static const _pillBg = Color.fromRGBO(64, 64, 64, 0.24);
  static const _honorBorder = Color.fromRGBO(215, 215, 217, 0.53);
  static const _statsBorder = Color.fromRGBO(98, 98, 98, 0.2);

  static const double _honorH = 35;
  static const double _statsH = 35;
  static const double _honorW = 90;
  static const double _statsW = 103;

  static const double _radius = 4;
  static const double _honorBorderWidth = 0.8;
  static const double _statsBorderWidth = 1;
  static const double _honorInnerGap = 4;
  static const double _statsInnerGap = 6;
  static const double _betweenChips = 6;

  static const EdgeInsets _honorPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);
  static const EdgeInsets _statsPadding = EdgeInsets.fromLTRB(10, 2, 10, 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final betweenGap = _betweenChips;
        final minHonorW = 74.0;
        final minStatsW = 92.0;

        double statsW = _statsW;
        double honorW = _honorW;

        final desired = honorW + betweenGap + statsW;
        if (desired > available) {
          final overflow = desired - available;
          honorW = (honorW - overflow).clamp(minHonorW, honorW);
        }

        final totalAfterHonor = honorW + betweenGap + statsW;
        if (totalAfterHonor > available) {
          final overflow = totalAfterHonor - available;
          statsW = (statsW - overflow).clamp(minStatsW, statsW);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: honorW,
                height: _honorH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _pillBg,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(
                      color: _honorBorder,
                      width: _honorBorderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: _honorPadding,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Assets.images.goldenHonor.image(
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                            excludeFromSemantics: true,
                          ),
                        ),
                        const Gap(_honorInnerGap),
                        Flexible(
                          child: Text(
                            goldenSeals.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyles.titleTag.copyWith(
                          fontFamily: 'CanelaDeckTrial',
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 16 / 18,
                          color: const Color(0xFFFFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Gap(betweenGap),
            SizedBox(
              width: statsW,
              height: _statsH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: _statsBorder,
                    width: _statsBorderWidth,
                  ),
                ),
                child: Padding(
                  padding: _statsPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Assets.icons.statsIcon.svg(
                        width: 13,
                        height: 13,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFCACACA),
                          BlendMode.srcIn,
                        ),
                      ),
                      const Gap(_statsInnerGap),
                      Expanded(
                        child: Text(
                          statsLabel,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.titleTag.copyWith(
                            fontFamily: 'CanelaDeckTrial',
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            height: 16 / 15,
                            letterSpacing: -0.3,
                            color: const Color(0xFFCACACA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
