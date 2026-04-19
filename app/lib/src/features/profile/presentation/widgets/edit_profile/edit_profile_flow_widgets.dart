import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditProfileFlowAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const EditProfileFlowAppBar({
    super.key,
    this.title,
    this.actionLabel,
    this.onActionTap,
    this.isActionEnabled = true,
    this.trailing,
  });

  final String? title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final bool isActionEnabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.colorff19191A,
      surfaceTintColor: AppColors.colorff19191A,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Center(
          child: Assets.icons.arrowBack.svg(
            width: 20,
            height: 20,
          ),
        ),
      ),
      title: title == null
          ? null
          : Text(
              title!,
              style: TextStyles.titleMain.copyWith(
                color: AppColors.textBrand,
              ),
            ),
      actions: [
        if (actionLabel != null)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: isActionEnabled ? onActionTap : null,
              child: Center(
                child: Text(
                  actionLabel!,
                  style: TextStyles.titleMain.copyWith(
                    color: isActionEnabled
                        ? AppColors.textBrand
                        : const Color(0xFFA3A3A3),
                  ),
                ),
              ),
            ),
          )
        else if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(child: trailing),
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class EditProfileSectionLabel extends StatelessWidget {
  const EditProfileSectionLabel({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyles.bodyLarge.copyWith(
        color: const Color(0xFFA3A3A3),
        height: 1.4,
      ),
    );
  }
}

class EditProfileValueCardRow extends StatelessWidget {
  const EditProfileValueCardRow({
    required this.value,
    required this.onTap,
    super.key,
    this.prefixAtSign = false,
    this.placeholder,
  });

  final String value;
  final VoidCallback onTap;
  final bool prefixAtSign;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final trimmedValue = value.trim();
    final displayValue = trimmedValue.isEmpty
        ? (placeholder ?? '')
        : prefixAtSign
            ? '@$trimmedValue'
            : trimmedValue;
    final isPlaceholder = trimmedValue.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.bodyLarge.copyWith(
                      fontSize: 18,
                      height: 1,
                      color: isPlaceholder
                          ? const Color(0xFFA3A3A3)
                          : AppColors.textBrand,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: Color(0xFFA3A3A3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditProfileCounterText extends StatelessWidget {      
  const EditProfileCounterText({
    required this.currentLength,
    required this.maxLength,
    super.key,
    this.textAlign = TextAlign.left,
  });

  final int currentLength;
  final int maxLength;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$currentLength/$maxLength',
      textAlign: textAlign,
      style: TextStyles.bodyMain.copyWith(
        fontSize: 12,
        height: 1.25,
        color: const Color(0xFFA3A3A3),
      ),
    );
  }
}

class EditProfileNicknameInput extends StatelessWidget {
  const EditProfileNicknameInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    super.key,
    this.maxLength = 50,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: 'Nickname',
      hintText: 'Enter nickname',
      onChanged: onChanged,
      showLabel: false,
      height: 46,
      backgroundColor: Colors.transparent,
      borderRadius: 8,
      customBorder: Border.all(color: AppColors.textBrand),
      containerPadding: const EdgeInsets.symmetric(horizontal: 12),
      contentPadding: EdgeInsets.zero,
      textStyle: TextStyles.bodyLarge.copyWith(
        color: AppColors.textBrand,
      ),
      hintStyle: TextStyles.bodyLarge.copyWith(
        color: const Color(0xFFA3A3A3),
      ),
      prefixIcon: Text(
        '@',
        style: TextStyles.titleHeadline.copyWith(
          color: AppColors.textBrand,
        ),
      ),
      suffixIcon: controller.text.isNotEmpty
          ? GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textBrand,
              ),
            )
          : null,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp('@')),
        LengthLimitingTextInputFormatter(maxLength),
      ],
    );
  }
}

class EditProfileBioInput extends StatelessWidget {
  const EditProfileBioInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    super.key,
    this.maxLength = 500,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: 'Bio',
      hintText: 'Write your bio',
      onChanged: onChanged,
      showLabel: false,
      minLines: 5,
      maxLines: 5,
      height: 152,
      backgroundColor: Colors.transparent,
      borderRadius: 12,
      customBorder: Border.all(color: AppColors.textBrand),
      containerPadding: const EdgeInsets.all(16),
      contentPadding: EdgeInsets.zero,
      textStyle: TextStyles.bodyLarge.copyWith(
        fontSize: 18,
        height: 1.25,
        color: AppColors.textBrand,
      ),
      hintStyle: TextStyles.bodyLarge.copyWith(
        fontSize: 18,
        color: const Color(0xFFA3A3A3),
      ),
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
      ],
    );
  }
}
