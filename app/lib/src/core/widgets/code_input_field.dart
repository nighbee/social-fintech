import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeInputField extends StatefulWidget {
  const CodeInputField({super.key, required this.length, this.onChanged});

  final int length;
  final ValueChanged<String>? onChanged;

  @override
  State<CodeInputField> createState() => _CodeInputFieldState();
}

class _CodeInputFieldState extends State<CodeInputField> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.length; i++) {
      _controllers.add(TextEditingController());
      final focusNode = FocusNode();
      focusNode.addListener(() {
        setState(() {});
      });
      _focusNodes.add(focusNode);
      _controllers[i].addListener(() {
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onChanged?.call(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.length,
        (index) => Padding(
          padding: EdgeInsets.only(right: index < widget.length - 1 ? 12 : 0),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.textGray2, width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_controllers[index].text.isEmpty &&
                      !_focusNodes[index].hasFocus)
                    Positioned(
                      bottom: 18,
                      child: Container(
                        width: 20,
                        height: 1.5,
                        color: AppColors.textGray2,
                      ),
                    ),
                  TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    style: context.theme.textStyles.inputText.copyWith(
                      fontSize: 24,
                      color: AppColors.textGray1,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty && index < widget.length - 1) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        _onChanged();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
