import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeInputField extends StatefulWidget {
  const CodeInputField({
    super.key,
    required this.length,
    this.onChanged,
    this.allowAlphanumeric = false,
    this.isInvalid = false,
  });

  final int length;
  final ValueChanged<String>? onChanged;
  final bool allowAlphanumeric;
  final bool isInvalid;

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_syncState);
    _controller.addListener(_syncState);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_syncState);
    _controller.removeListener(_syncState);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _syncState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _emitCode() {
    widget.onChanged?.call(_controller.text);
  }

  String _normalizedValue(String raw) {
    final source = widget.allowAlphanumeric
        ? raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')
        : raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (source.length <= widget.length) {
      return source;
    }
    return source.substring(0, widget.length);
  }

  void _handleChanged(String value) {
    final normalized = _normalizedValue(value);
    if (normalized != _controller.text) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    _emitCode();
  }

  int get _activeCellIndex {
    if (_controller.text.length >= widget.length) {
      return widget.length - 1;
    }
    return _controller.text.length;
  }

  void _focusInput() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isInvalid ? const Color(0xFFEF4444) : AppColors.colorffcacaca;
    final borderColor =
        widget.isInvalid ? const Color(0xFFEF4444) : AppColors.colorff838383;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusInput,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            width: 1,
            height: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: widget.allowAlphanumeric
                  ? TextInputType.visiblePassword
                  : TextInputType.number,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(fontSize: 1, color: Colors.transparent),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                widget.allowAlphanumeric
                    ? FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))
                    : FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              onChanged: _handleChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.length,
              (index) {
                final cellValue = index < _controller.text.length
                    ? _controller.text[index]
                    : '';
                final isActive = _focusNode.hasFocus &&
                    index == _activeCellIndex &&
                    cellValue.isEmpty;

                return Padding(
                  padding:
                      EdgeInsets.only(right: index < widget.length - 1 ? 8 : 0),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (cellValue.isEmpty && !isActive)
                            Positioned(
                              bottom: 14,
                              child: Container(
                                width: 16,
                                height: 1.5,
                                color: borderColor,
                              ),
                            ),
                          if (isActive)
                            Container(
                              width: 3,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6CB6FF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          if (cellValue.isNotEmpty)
                            Text(
                              cellValue,
                              style: TextStyles.titleMain.copyWith(
                                fontSize: 20,
                                color: textColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
