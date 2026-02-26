import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class CustomTextField extends StatefulWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
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
    this.showBorder = true,
    this.customBorder,
    this.backgroundColor,
    this.height,
    this.showLabel = true,
    this.showLabelOnlyWhenHasText = false,
    this.onLabelVisibilityChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
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
  final bool showBorder;
  final BoxBorder? customBorder;
  final Color? backgroundColor;
  final double? height;
  final bool showLabel;
  final bool showLabelOnlyWhenHasText;
  final ValueChanged<bool>? onLabelVisibilityChanged;

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _hasValidationError = false;
  String? _errorText;
  bool? _lastReportedLabelVisibility;

  bool _isLabelVisible(bool hasText) {
    if (!widget.showLabel) return false;
    if (widget.showLabelOnlyWhenHasText) return hasText;
    return true;
  }

  void _notifyLabelVisibilityIfChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    final isVisible = _isLabelVisible(hasText);
    if (_lastReportedLabelVisibility == isVisible) return;
    _lastReportedLabelVisibility = isVisible;
    widget.onLabelVisibilityChanged?.call(isVisible);
  }

  void _onTextChanged() {
    _notifyLabelVisibilityIfChanged();
    setState(() {});
  }

  String? _validate(String? value) {
    final error = widget.validator?.call(value);
    final hasError = error != null;

    if (_hasValidationError != hasError || _errorText != error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hasValidationError = hasError;
          _errorText = error;
        });
      });
    }

    return error;
  }

  @override
  void initState() {
    super.initState();
    _notifyLabelVisibilityIfChanged();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showLabel != widget.showLabel ||
        oldWidget.showLabelOnlyWhenHasText != widget.showLabelOnlyWhenHasText) {
      _notifyLabelVisibilityIfChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final showLabel = _isLabelVisible(hasText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: widget.height ?? 64,
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 8.5),
          decoration: BoxDecoration(
            border: widget.showBorder
                ? (_hasValidationError
                    ? Border.all(color: AppColors.error, width: 1)
                    : (widget.customBorder ??
                        Border.all(color: AppColors.whiteBackground, width: 1)))
                : null,
            borderRadius: BorderRadius.circular(6),
            color: widget.backgroundColor ?? context.theme.mainBackground,
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
                    if (showLabel)
                      Text(widget.labelText, style: TextStyles.bodyMain),
                    TextFormField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      onChanged: (value) {
                        widget.onChanged?.call(value);
                      },
                      keyboardType: widget.keyboardType,
                      validator: _validate,
                      obscureText: widget.obscureText,
                      readOnly: widget.readOnly,
                      onTap: widget.onTap,
                      inputFormatters: widget.inputFormatters,
                      textAlignVertical: hasText
                          ? TextAlignVertical.top
                          : TextAlignVertical.center,
                      style: TextStyles.titleHeadline,
                      decoration: InputDecoration(
                        hintText: hasText
                            ? null
                            : (widget.hintText ?? widget.labelText),
                        hintStyle: TextStyles.titleTag,
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
                        errorStyle: const TextStyle(fontSize: 0, height: 0),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.suffixIcon != null) widget.suffixIcon!,
            ],
          ),
        ),
        if ((_errorText ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              _errorText!,
              style: TextStyles.titleTag.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
