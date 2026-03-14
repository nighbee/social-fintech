import 'dart:io';

import 'package:app/gen/assets.gen.dart';
import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ReportBugPage extends StatefulWidget {
  const ReportBugPage({super.key});

  @override
  State<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final TextEditingController _controller = TextEditingController();
  XFile? _attachment;

  bool get _canSend => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {});
  }

  Future<void> _pickAttachment() async {
    await ImagePickerHelper.showImagePickerFile(
      context: context,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
      onImageSelected: (file) {
        setState(() {
          _attachment = file;
        });
      },
    );
  }

  void _send() {
    if (!_canSend) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.colorff19191A,
      appBar: AppBar(
        backgroundColor: AppColors.colorff19191A,
        surfaceTintColor: AppColors.colorff19191A,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 48,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Center(
            child: Assets.icons.arrowBack.svg(
              width: 20,
              height: 20,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSend ? _send : null,
            child: Text(
              'Send',
              style: TextStyles.titleMain.copyWith(
                color: _canSend
                    ? AppColors.colorffffffff
                    : AppColors.colorffa9a9a9,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 22 / 20,
              ),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: false,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        cursorColor: AppColors.colorffffffff,
                        style: TextStyles.titleMain.copyWith(
                          color: AppColors.colorffffffff,
                          fontFamily: FontFamily.canelaDeckTrial,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 22 / 20,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          hintText:
                              '|Describe the issue and steps to reproduce it',
                          hintStyle: TextStyles.titleMain.copyWith(
                            color: AppColors.colorffa9a9a9,
                            fontFamily: FontFamily.canelaDeckTrial,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            height: 22 / 20,
                          ),
                          filled: true,
                          fillColor: AppColors.colorff19191A,
                        ),
                      ),
                    ),
                    if (_attachment != null) ...[
                      const Gap(20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_attachment!.path),
                          width: 60,
                          height: 130,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 130,
                            decoration: BoxDecoration(
                              color: AppColors.colorff202020,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.colorff838383,
                            ),
                          ),
                        ),
                      ),
                      const Gap(24),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderDefault,
                    width: 1,
                  ),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickAttachment,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 10, 10, 16),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: AppColors.colorffffffff,
                            size: 22,
                          ),
                          const Gap(10),
                          Text(
                            'Upload',
                            style: TextStyles.bodyMain.copyWith(
                              color: AppColors.colorffffffff,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
