import 'dart:io';

import 'package:app/gen/assets.gen.dart';
import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

const int _kMaxBugAttachments = 5;

class ReportBugPage extends StatefulWidget {
  const ReportBugPage({super.key});

  @override
  State<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final TextEditingController _controller = TextEditingController();
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  final List<XFile> _attachments = [];
  bool _isSending = false;

  bool get _canSend =>
      _controller.text.trim().isNotEmpty && !_isSending;

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
    if (_attachments.length >= _kMaxBugAttachments) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can add up to $_kMaxBugAttachments photos.',
            style: TextStyles.bodyMain.copyWith(color: AppColors.colorffffffff),
          ),
          backgroundColor: AppColors.colorff202020,
        ),
      );
      return;
    }

    await ImagePickerHelper.showImagePickerFile(
      context: context,
      imageQuality: 85,
      maxWidth: null,
      maxHeight: null,
      onImageSelected: (file) {
        setState(() {
          _attachments.add(file);
        });
      },
    );
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _send() async {
    final description = _controller.text.trim();
    if (description.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceOS =
        '${Platform.isAndroid ? 'Android' : 'iOS'} ${Platform.operatingSystemVersion}';

    try {
      late final Either<DomainException, void> outcome;

      if (_attachments.isEmpty) {
        outcome = await _remote.reportBug(
          description: description,
          screenshotFilePath: null,
          appVersion: packageInfo.version,
          deviceOS: deviceOS,
        );
      } else {
        Either<DomainException, void> last = const Right(null);
        for (final file in _attachments) {
          last = await _remote.reportBug(
            description: description,
            screenshotFilePath: file.path,
            appVersion: packageInfo.version,
            deviceOS: deviceOS,
          );
          if (last.isLeft()) {
            break;
          }
        }
        outcome = last;
      }

      if (!mounted) return;

      await outcome.fold(
        (err) async {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                err.message,
                style: TextStyles.bodyMain
                    .copyWith(color: AppColors.colorffffffff),
              ),
              backgroundColor: AppColors.colorff202020,
            ),
          );
        },
        (_) async {
          if (!mounted) return;
          context.pop(true);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
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
                              'Describe the issue and steps to reproduce it',
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
                    if (_attachments.isNotEmpty) ...[
                      const Gap(16),
                      SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachments.length,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (context, index) {
                            return _BugAttachmentTile(
                              path: _attachments[index].path,
                              onRemove: () => _removeAttachment(index),
                            );
                          },
                        ),
                      ),
                      const Gap(16),
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

class _BugAttachmentTile extends StatelessWidget {
  const _BugAttachmentTile({
    required this.path,
    required this.onRemove,
  });

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 130,
              maxWidth: 200,
            ),
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                height: 130,
                width: 80,
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
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.colorffffffff,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
