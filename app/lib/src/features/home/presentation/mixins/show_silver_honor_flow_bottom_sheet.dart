import 'dart:ui' show ImageFilter;

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/silver_balance_chip.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/home/domain/entities/post_entity.dart';
import 'package:app/src/features/home/presentation/widgets/honor_compose_surface.dart';
import 'package:flutter/material.dart';

class HonorCommentPreview {
  const HonorCommentPreview({
    required this.userName,
    required this.subtitle,
    required this.commentPreview,
    required this.avatarUrl,
  });

  final String userName;
  final String subtitle;
  final String commentPreview;
  final String avatarUrl;
}

mixin ShowSilverHonorBottomSheet {
  void showSilverHonorBottomSheet(
    BuildContext context, {
    required PostEntity post,
  }) {
    final commentPreviews = _buildCommentPreviews(post);
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.2,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: _SilverHonorListSheet(
          commentPreviews: commentPreviews,
          onSendTap: () => _showSilverHonorComposeDialog(context),
        ),
      ),
    );
  }

  void _showSilverHonorComposeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: const _SilverHonorComposeFlowDialog(),
        );
      },
    );
  }

  List<HonorCommentPreview> _buildCommentPreviews(PostEntity post) {
    final authorAvatar = post.userAvatar ??
        (post.imageUrls.isNotEmpty ? post.imageUrls.first : '');
    return [
      HonorCommentPreview(
        userName: post.username,
        subtitle: 'Moonstone • Intention • A',
        commentPreview: 'Awesome!',
        avatarUrl: authorAvatar,
      ),
      const HonorCommentPreview(
        userName: 'Merey Zhumagul',
        subtitle: 'Moonstone • Intention • A',
        commentPreview: 'Every time I read thoughts like this about...',
        avatarUrl: 'https://i.pravatar.cc/150?img=45',
      ),
      const HonorCommentPreview(
        userName: 'Zhanar Yesmoldayeva',
        subtitle: 'Moonstone • Intention • A',
        commentPreview: 'Awesome!',
        avatarUrl: 'https://i.pravatar.cc/150?img=46',
      ),
      const HonorCommentPreview(
        userName: 'Merey Zhanel',
        subtitle: 'Moonstone • Intention • A',
        commentPreview: 'Every time I read thoughts like this about...',
        avatarUrl: 'https://i.pravatar.cc/150?img=32',
      ),
    ];
  }
}

enum _SilverHonorDialogStage { compose, success }

class _SilverHonorComposeFlowDialog extends StatefulWidget {
  const _SilverHonorComposeFlowDialog();

  @override
  State<_SilverHonorComposeFlowDialog> createState() =>
      _SilverHonorComposeFlowDialogState();
}

class _SilverHonorComposeFlowDialogState
    extends State<_SilverHonorComposeFlowDialog> {
  _SilverHonorDialogStage _stage = _SilverHonorDialogStage.compose;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _SilverHonorDialogStage.success) {
      return _SilverHonorSuccessSheet(
        onDoneTap: () => Navigator.of(context).pop(),
      );
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: HonorComposeSurface(
              child: _SilverHonorSendSheet(
                controller: _messageController,
                onCancel: () => Navigator.of(context).pop(),
                onSend: () => setState(
                  () => _stage = _SilverHonorDialogStage.success,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SilverHonorListSheet extends StatelessWidget {
  const _SilverHonorListSheet({
    required this.commentPreviews,
    required this.onSendTap,
  });

  final List<HonorCommentPreview> commentPreviews;
  final VoidCallback onSendTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101214).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Silver Honor',
                style: TextStyles.titleHeadline.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: commentPreviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = commentPreviews[index];
                  return _SilverHonorCommentPreviewTile(item: item);
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Future<void>.delayed(
                      const Duration(milliseconds: 120), onSendTap);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B7B7D),
                  foregroundColor: const Color(0xFFF1F1F1),
                  elevation: 0,
                  minimumSize: const Size.fromHeight(42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Send a silver honor',
                      style: TextStyles.bodyMain.copyWith(
                        color: const Color(0xFFF1F1F1),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Assets.icons.silverCoin.svg(width: 14, height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SilverHonorCommentPreviewTile extends StatelessWidget {
  const _SilverHonorCommentPreviewTile({required this.item});

  final HonorCommentPreview item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomNetworkImage(
          imageUrl: item.avatarUrl,
          width: 28,
          height: 28,
          borderRadius: BorderRadius.circular(7),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.userName,
                      style: TextStyles.bodyMain.copyWith(
                        color: const Color(0xFFE6E6E6),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      item.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.bodySecondary.copyWith(
                        color: const Color(0xFF8B8B8B),
                        fontSize: 10.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.commentPreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFFD5D5D5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SilverHonorSendSheet extends StatefulWidget {
  const _SilverHonorSendSheet({
    required this.controller,
    required this.onCancel,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_SilverHonorSendSheet> createState() => _SilverHonorSendSheetState();
}

class _SilverHonorSendSheetState extends State<_SilverHonorSendSheet> {
  static const int maxLength = 500;

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

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 1),
          const SilverBalanceChip.live(compact: true),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'What would you like to convey along with\nthe honor?',
              textAlign: TextAlign.center,
              style: TextStyles.titleHeadline.copyWith(
                color: AppColors.whiteBackground,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.icons.silverCoin.svg(width: 17, height: 17),
                const SizedBox(width: 8),
                Text(
                  '1',
                  style: TextStyles.titleTag.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: HonorComposeGlass.messageFieldFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HonorComposeGlass.messageFieldBorder),
            ),
            child: Stack(
              children: [
                TextField(
                  controller: widget.controller,
                  maxLength: maxLength,
                  minLines: 4,
                  maxLines: 4,
                  style: TextStyles.bodyMain.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Text Area',
                    hintStyle:
                        TextStyles.bodyMain.copyWith(color: Colors.white38),
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.all(12),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                if (widget.controller.text.trim().isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => widget.controller.clear(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${widget.controller.text.characters.length}/$maxLength',
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFF8A8A8A),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Send',
            onTap: widget.onSend,
            isDisabled: !canSend,
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(vertical: 11),
            backgroundColor: AppColors.backgroundBrandLight,
            textStyle: TextStyles.bodyMain.copyWith(
              color: AppColors.textNeutral,
              fontWeight: FontWeight.w600,
            ),
            disabledBackgroundColor: AppColors.backgroundDisabledDefault,
            disabledTextStyle: TextStyles.bodyMain.copyWith(
              color: AppColors.textDisabledDefault,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Cancel',
            onTap: widget.onCancel,
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(vertical: 11),
            backgroundColor: Colors.transparent,
            border: Border.all(
              color: AppColors.borderDefault,
              width: 0.8,
            ),
            textStyle: TextStyles.bodyMain.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SilverHonorSuccessSheet extends StatelessWidget {
  const _SilverHonorSuccessSheet({required this.onDoneTap});

  final VoidCallback onDoneTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x45282930),
                    const Color(0x52111418),
                    const Color(0x451F232A),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  padding.top + 8,
                  24,
                  16 + padding.bottom,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onDoneTap,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Thank you!',
                      style: TextStyles.titleHeadline.copyWith(
                        color: AppColors.whiteBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your silver honor has been sent successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    CustomButton(
                      text: 'Great!',
                      onTap: onDoneTap,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.transparent,
                      border: Border.all(
                        color:
                            AppColors.whiteBackground.withValues(alpha: 0.88),
                        width: 0.8,
                      ),
                      textStyle: TextStyles.titleHeadline.copyWith(
                        color: AppColors.whiteBackground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
