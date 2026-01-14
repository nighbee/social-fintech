import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/code_input_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class CodePage extends StatefulWidget {
  const CodePage({super.key});

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  String _code = '';
  final String _phoneNumber = '787777065068';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: const CustomAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gap(40),
            Text(
              "Enter the code",
              style: context.theme.textStyles.codePageTitle,
            ),
            Gap(16),
            Text(
              "Enter the code we've sent by SMS to $_phoneNumber:",
              style: context.theme.textStyles.codePageSubtitle,
            ),
            Gap(40),
            Center(
              child: CodeInputField(
                length: 4,
                onChanged: (code) {
                  setState(() {
                    _code = code;
                  });
                },
              ),
            ),
            Gap(40),
            CustomButton(
              text: "Continue",
              onTap: () {
                // if (_code.length == 4) {}

                context.pushNamed(RouteNames.info);
              },
            ),

            Gap(20),
          ],
        ),
      ),
    );
  }
}
