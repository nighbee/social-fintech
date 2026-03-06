import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TierIndicators extends StatelessWidget {
  const TierIndicators({
    super.key,
    required this.tiers,
    this.activeTiers = const [],
  });

  final List<String> tiers;
  final List<String> activeTiers;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: tiers.map((tier) {
        final isActive = activeTiers.contains(tier);
        return Column(
          children: [
            Text(
              tier,
              style: TextStyles.titleTag.copyWith(
                color: AppColors.colorffffffff,
                fontWeight: FontWeight.w500,
              ),
            ),
            Gap(4),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(0xFF3d3d3d),
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFF3d3d3d), width: 1.5),
                  ),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isActive ? Color(0xFF919191) : Color(0xFF000000),
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFF919191), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }
}
