import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ReferalPage extends StatefulWidget {
  const ReferalPage({super.key});

  @override
  State<ReferalPage> createState() => _ReferalPageState();
}

class _ReferalPageState extends State<ReferalPage> {
  final TextEditingController _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: CustomAppBar(
        title: 'Code',
        actions: [
          TextButton(
            onPressed: () {
              context.pushNamed(RouteNames.home);
            },
            child: Text(
              'Skip',
              style: context.theme.textStyles.codePageSubtitle.copyWith(
                color: AppColors.whiteBackground,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(40),
            Text(
              "Have you been invited?",
              style: context.theme.textStyles.codePageTitle,
            ),
            Gap(16),
            Text(
              "If you came based on a recommendation, specify the nickname of the person who invited you. We will give him 1 seal as a token of gratitude.",
              style: context.theme.textStyles.codePageSubtitle,
            ),
            Gap(40),
            CustomTextField(
              controller: _nicknameController,
              labelText: "Nickname",
              hintText: "",
              prefixIcon: Assets.icons.atsign.svg(
                width: 30,
                height: 30,
                colorFilter: const ColorFilter.mode(
                  AppColors.whiteBackground,
                  BlendMode.srcIn,
                ),
              ),
              suffixIcon: _nicknameController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _nicknameController.clear();
                        });
                      },
                      child: Assets.icons.close.svg(
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          AppColors.textGray2,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : null,
              onChanged: (value) {
                setState(() {});
              },
            ),
            Gap(40),
            CustomButton(
              text: "Confirm",
              onTap: () {
                context.pushNamed(RouteNames.home);
              },
            ),
          ],
        ),
      ),
    );
  }
}
