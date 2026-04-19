import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/constants/ui_constants.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({required this.goldenSeals, super.key});

  final int goldenSeals;

  static const _pillBg = Color(0xFF3A3533);
  static const _pillBorder = Color(0xFF4B4643);

  static const double _honorH = 41;
  static const double _statsH = 41;

  static const double _radius = 4;
  static const double _borderWidth = 1;
  static const double _innerGap = 6;
  static const double _betweenChips = 6;

  static const EdgeInsets _honorPadding =
      EdgeInsets.all(UIConstants.defaultGap1);
  static const EdgeInsets _statsPadding = EdgeInsets.fromLTRB(10, 4, 10, 4);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Opacity(
            opacity: 0.8,
            child: SizedBox(
              height: _honorH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: _pillBorder,
                    width: _borderWidth,
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
                      const Gap(_innerGap),
                      Flexible(
                        child: Text(
                          goldenSeals.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 18 / 15,
                            color: AppColors.colorffE5E5E5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Gap(_betweenChips),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: _statsH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _pillBg,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: _pillBorder,
                  width: _borderWidth,
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
                    const Gap(_innerGap),
                    Expanded(
                      child: Text(
                        'Your Stats',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.bodyMain.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 17 / 14,
                          color: AppColors.colorffE5E5E5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
