import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'terms_conditions_content.dart';

const Color _kTermsDateColor = Color(0xFF78869B);

const Color _kTermsBodyColor = Color(0xFFE5E5E5);

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: FontFamily.canelaDeckTrial,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.colorffffffff,
    height: 38 / 32,
  );

  static const TextStyle _sectionTitleStyle = TextStyle(
    fontFamily: FontFamily.canelaDeckTrial,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: AppColors.colorffffffff,
    height: 22 / 17,
  );

  static const TextStyle _summaryStyle = TextStyle(
    fontFamily: FontFamily.lora,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.colorffffffff,
    height: 1.4,
  );

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: FontFamily.lora,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: _kTermsBodyColor,
    height: 1.45,
  );

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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms & Conditions',
                style: _titleStyle,
              ),
              const Gap(12),
              Text(
                kTermsLastUpdated,
                style: TextStyles.bodyLarge.copyWith(
                  color: _kTermsDateColor,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const Gap(22),
              for (var i = 0; i < kTermsSections.length; i++) ...[
                _TermsSection(
                  section: kTermsSections[i],
                  sectionTitleStyle: _sectionTitleStyle,
                  summaryStyle: _summaryStyle,
                  bodyStyle: _bodyStyle,
                ),
                if (i != kTermsSections.length - 1) const Gap(22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  const _TermsSection({
    required this.section,
    required this.sectionTitleStyle,
    required this.summaryStyle,
    required this.bodyStyle,
  });

  final TermsSectionData section;
  final TextStyle sectionTitleStyle;
  final TextStyle summaryStyle;
  final TextStyle bodyStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: sectionTitleStyle,
        ),
        const Gap(12),
        Text(
          section.summary,
          style: summaryStyle,
        ),
        const Gap(12),
        for (final paragraph in section.paragraphs) ...[
          Text(
            paragraph,
            style: bodyStyle,
          ),
          const Gap(12),
        ],
        if (section.bullets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bullet in section.bullets) ...[
                  _TermsBullet(text: bullet, style: bodyStyle),
                  const Gap(10),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TermsBullet extends StatelessWidget {
  const _TermsBullet({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: _kTermsBodyColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Text(
            text,
            style: style,
          ),
        ),
      ],
    );
  }
}
