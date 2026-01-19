import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.onChanged,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.onTap,
    this.readOnly = false,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final VoidCallback? onTap;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  void _onTextChanged() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 8.5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.whiteBackground, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.prefixIcon != null) ...[widget.prefixIcon!, Gap(12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasText)
                  Text(
                    widget.labelText,
                    style: Theme.of(context).textStyles.caption,
                  ),
                TextFormField(
                  controller: widget.controller,
                  onChanged: (value) {
                    widget.onChanged?.call(value);
                  },
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  obscureText: widget.obscureText,
                  readOnly: widget.readOnly,
                  onTap: widget.onTap,
                  inputFormatters: widget.inputFormatters,
                  textAlignVertical: hasText
                      ? TextAlignVertical.top
                      : TextAlignVertical.center,
                  style: Theme.of(context).textStyles.bodyLarge,
                  decoration: InputDecoration(
                    hintText: hasText
                        ? null
                        : (widget.hintText ?? widget.labelText),
                    hintStyle: Theme.of(context).textStyles.bodySmall,
                    contentPadding: hasText
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(vertical: 0),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          if (widget.suffixIcon != null) widget.suffixIcon!,
        ],
      ),
    );
  }
}
