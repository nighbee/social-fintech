import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:app/src/features/profile/presentation/utils/mock_ranks_data.dart';
import 'package:app/src/features/profile/presentation/widgets/rangs/rank_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RangsPage extends StatelessWidget {
  const RangsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color(0xFF16171A),
            child: const IgnorePointer(
              child: ParticleAnimation(
                particleCount: 18,
                particleColors: [Color(0xFFFFFFFF)],
                minSize: 3,
                maxSize: 6,
                minDistanceBetweenParticles: 72,
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: CustomAppBar(
            title: 'Rang',
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Assets.icons.more.svg(
                    width: 18,
                    height: 18,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    children: [
                      for (var index = 0; index < mockRanks.length; index++) ...[
                        if (mockRanks[index].thresholdLabelAbove != null)
                          _RankThresholdLabel(
                            label: mockRanks[index].thresholdLabelAbove!,
                          ),
                        RankCard(rank: mockRanks[index]),
                        if (index < mockRanks.length - 1) const Gap(20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankThresholdLabel extends StatelessWidget {
  const _RankThresholdLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyles.bodyLarge.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: const Color(0xFFDBD6C9),
        ),
      ),
    );
  }
}
