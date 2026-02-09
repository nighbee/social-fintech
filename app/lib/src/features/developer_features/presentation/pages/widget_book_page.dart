import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WidgetBookPage extends StatefulWidget {
  const WidgetBookPage({super.key});

  @override
  State<WidgetBookPage> createState() => _WidgetBookPageState();
}

class _WidgetBookPageState extends State<WidgetBookPage> {
  final TextEditingController _textFieldController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _readOnlyController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _readOnlyController.text = 'Read-only text';
  }

  @override
  void dispose() {
    _textFieldController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _readOnlyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: const CustomAppBar(title: 'Widget Book'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: 'Buttons',
            children: [
              CustomButton(text: 'Primary Button', onTap: () {}),
              Gap(16),
              CustomButton(
                text: 'Disabled Button',
                onTap: () {},
                isDisabled: true,
              ),
              Gap(16),
              CustomButton(
                text: 'Button with Icon',
                onTap: () {},
                icon: const Icon(Icons.add, color: Colors.white),
              ),
              Gap(16),
              CustomButton(
                text: 'Custom Width Button',
                onTap: () {},
                width: 250,
              ),
              Gap(16),
              CustomOutlinedButton(text: 'Outlined Button', onTap: () {}),
              Gap(16),
              CustomOutlinedButton(
                text: 'Custom Border Color',
                onTap: () {},
                borderColor: AppColors.blueText1,
                textStyle: TextStyles.titleMain.copyWith(
                  color: AppColors.blueText1,
                ),
              ),
            ],
          ),
          Gap(40),
          _buildSection(
            title: 'Text Fields',
            children: [
              CustomTextField(
                controller: _textFieldController,
                labelText: 'Text Field',
                hintText: 'Enter text',
              ),
              Gap(16),
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                hintText: 'Enter email',
                keyboardType: TextInputType.emailAddress,
              ),
              Gap(16),
              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                keyboardType: TextInputType.phone,
              ),
              Gap(16),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                hintText: 'Enter password',
                obscureText: !_isPasswordVisible,
                suffixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _isPasswordVisible
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeOpened.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 20,
                            width: 20,
                            child: Assets.icons.eyeClosed.svg(
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textGray2,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Gap(16),
              CustomTextField(
                controller: _readOnlyController,
                labelText: 'Read Only Field',
                hintText: 'Read only',
                readOnly: true,
              ),
              Gap(16),
              CustomTextField(
                controller: TextEditingController(),
                labelText: 'With Prefix Icon',
                hintText: 'Search',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Icon(Icons.search, color: AppColors.textGray2),
                ),
              ),
            ],
          ),
          Gap(40),
          _buildSection(
            title: 'App Bar',
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.theme.mainBackground,
                  border: Border.all(color: AppColors.whiteBackground),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const CustomAppBar(title: 'App Bar with Title'),
              ),
              Gap(16),
              Container(
                decoration: BoxDecoration(
                  color: context.theme.mainBackground,
                  border: Border.all(color: AppColors.whiteBackground),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const CustomAppBar(showLeading: false),
              ),
            ],
          ),
          Gap(40),
          _buildSection(
            title: 'Typography',
            children: [
              Text('Title Large', style: TextStyles.titleBig),
              Gap(8),
              Text('Title Headline', style: TextStyles.titleHeadline),
              Gap(8),
              Text('Code Page Title', style: TextStyles.titleXBig),
              Gap(8),
              Text('Code Page Subtitle', style: TextStyles.bodyLarge),
              Gap(8),
              Text('Input Text', style: TextStyles.titleMain),
              Gap(8),
              Text('Label Text', style: TextStyles.bodyMain),
              Gap(8),
              Text('Button Text', style: TextStyles.titleMain),
              Gap(8),
              Text('Hint Text', style: TextStyles.bodyMain),
            ],
          ),
          Gap(40),
          _buildSection(
            title: 'Colors',
            children: [
              _buildColorItem('Main Background', AppColors.mainBackground),
              Gap(8),
              _buildColorItem('Black Background', AppColors.blackBackground),
              Gap(8),
              _buildColorItem('White Background', AppColors.whiteBackground),
              Gap(8),
              _buildColorItem('Blue Text 1', AppColors.blueText1),
              Gap(8),
              _buildColorItem('Text Gray 2', AppColors.textGray2),
              Gap(8),
              _buildColorItem('Button Gray 1', AppColors.btnGray1),
              Gap(8),
              _buildColorItem('Button Gray 2', AppColors.btnGray2),
            ],
          ),
          Gap(40),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyles.titleBig),
        Gap(20),
        ...children,
      ],
    );
  }

  Widget _buildColorItem(String name, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: AppColors.whiteBackground, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Gap(12),
        Text(name, style: TextStyles.bodyMain),
      ],
    );
  }
}
