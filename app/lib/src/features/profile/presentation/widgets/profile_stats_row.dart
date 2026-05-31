import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({
    required this.goldenSeals,
    this.statsLabel = 'Your Stats',
    this.onTap,
    super.key,
  });

  final int goldenSeals;
  final String statsLabel;
  final VoidCallback? onTap;

  static const _pillBg = Color(0xFF303030);
  static const _honorBorder = Color.fromRGBO(215, 215, 217, 0.53);
  static const _statsBorder = Color.fromRGBO(98, 98, 98, 0.2);

  static const double _honorH = 35;
  static const double _statsH = 35;
  static const double _honorW = 60;
  static const double _statsW = 110;
  static const double _minHonorW = 52;
  static const double _minStatsW = 104;
  static const double _radius = 4;
  static const double _honorBorderWidth = 0.8;
  static const double _statsBorderWidth = 1;
  static const double _honorInnerGap = 5;
  static const double _statsInnerGap = 5;
  static const double _betweenChips = 6;

  static const EdgeInsets _honorPadding = EdgeInsets.fromLTRB(7, 4, 7, 4);
  static const EdgeInsets _statsPadding = EdgeInsets.fromLTRB(10, 2, 6, 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        var honorW = _honorW;
        var statsW = _statsW;

        if (maxWidth.isFinite) {
          final desired = honorW + _betweenChips + statsW;
          final overflow = desired - maxWidth;
          if (overflow > 0) {
            honorW = (honorW - overflow).clamp(_minHonorW, _honorW);
          }
          final remainingOverflow = honorW + _betweenChips + statsW - maxWidth;
          if (remainingOverflow > 0) {
            statsW = (statsW - remainingOverflow).clamp(_minStatsW, _statsW);
          }
        }

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
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
                          width: 20,
                          height: 20,
                          child: Assets.images.goldenHonor.image(
                            width: 20,
                            height: 20,
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
              const Gap(_betweenChips),
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
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFCACACA),
                            BlendMode.srcIn,
                          ),
                        ),
                        const Gap(_statsInnerGap),
                        Text(
                          statsLabel,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyles.titleTag.copyWith(
                            fontFamily: 'CanelaDeckTrial',
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            height: 16 / 15,
                            color: const Color(0xFFCACACA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
