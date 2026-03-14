import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'terms_conditions_content.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms & Conditions',
                style: TextStyles.titleBig.copyWith(
                  color: AppColors.colorffffffff,
                  fontFamily: FontFamily.lora,
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  height: 38 / 32,
                ),
              ),
              const Gap(12),
              Text(
                kTermsLastUpdated,
                style: TextStyles.bodyLarge.copyWith(
                  color: const Color(0xFF5F6880),
                  height: 22 / 16,
                ),
              ),
              const Gap(10),
              for (var i = 0; i < kTermsSections.length; i++) ...[
                _TermsSection(section: kTermsSections[i]),
                if (i != kTermsSections.length - 1) const Gap(16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.section});

  final TermsSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: TextStyles.bodyLarge.copyWith(
            color: AppColors.colorffffffff,
            height: 22 / 16,
          ),
        ),
        const Gap(10),
        Text(
          section.summary,
          style: TextStyles.bodyLarge.copyWith(
            color: AppColors.colorffffffff,
            height: 22 / 16,
          ),
        ),
        const Gap(10),
        for (final paragraph in section.paragraphs) ...[
          Text(
            paragraph,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.colorffffffff,
              height: 22 / 16,
            ),
          ),
          const Gap(10),
        ],
        if (section.bullets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bullet in section.bullets) ...[
                  _TermsBullet(text: bullet),
                  const Gap(8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TermsBullet extends StatelessWidget {
  const _TermsBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.colorffffffff,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Text(
            text,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.colorffffffff,
              height: 22 / 16,
            ),
          ),
        ),
      ],
    );
  }
}
