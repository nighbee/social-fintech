import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:app/src/core/widgets/silver_balance_chip.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/entities/seal_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

mixin ShowPostSilverHonorBottomSheet {
  void showPostSilverHonorBottomSheet(
    BuildContext context, {
    required HomeBloc bloc,
    required PostResponseEntity post,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: const Color(0xFF161616),
      maxHeightFactor: 0.86,
      child: ActionBottomSheet(
        enableGlassEffect: false,
        backgroundColor: const Color(0xFF161616),
        child: PostSilverHonorBottomSheet(
          bloc: bloc,
          post: post,
        ),
      ),
    );
  }
}

class PostSilverHonorBottomSheet extends StatefulWidget {
  const PostSilverHonorBottomSheet({
    required this.bloc,
    required this.post,
    super.key,
  });

  final HomeBloc bloc;
  final PostResponseEntity post;

  @override
  State<PostSilverHonorBottomSheet> createState() =>
      _PostSilverHonorBottomSheetState();
}

class _PostSilverHonorBottomSheetState
    extends State<PostSilverHonorBottomSheet> {
  bool _isLoading = true;
  String? _loadError;
  List<SealResponseEntity> _seals = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSeals());
  }

  Future<void> _loadSeals() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final result = await widget.bloc.getPostSealsDirect(
      GetPostSealsRequest(postId: widget.post.postId),
    );

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isLoading = false;
          _loadError = error.message;
          _seals = const [];
        });
      },
      (seals) {
        setState(() {
          _isLoading = false;
          _loadError = null;
          _seals = seals.items;
        });
      },
    );
  }

  Future<void> _showSilverHonorComposerDialog(
    BuildContext context,
    PostResponseEntity currentPost,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (_) {
        return _SilverHonorComposerDialog(
          bloc: widget.bloc,
          postId: currentPost.postId,
          currentSealCount: currentPost.metrics.silvers,
          sheetContext: context,
        );
      },
    );
  }

  Widget _buildListContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _loadError!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                style: TextStyles.bodyMain.copyWith(
                  color: AppColors.colorffE5E5E5,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(16),
              CustomOutlinedButton(
                text: 'Retry',
                width: 140,
                borderRadius: 8,
                backgroundColor: Colors.transparent,
                onTap: _loadSeals,
              ),
            ],
          ),
        ),
      );
    }

    if (_seals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No silver honors yet.',
            style: TextStyles.bodyMain.copyWith(
              color: AppColors.colorffE5E5E5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _seals.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (context, index) {
        return _SilverHonorListItem(item: _seals[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: widget.bloc,
      builder: (context, state) {
        final viewModel = state.maybeWhen(
          loading: (viewModel) => viewModel,
          loaded: (viewModel) => viewModel,
          orElse: HomeViewModel.new,
        );
        final currentPost = viewModel.feed.items.firstWhere(
          (item) => item.postId == widget.post.postId,
          orElse: () => widget.post,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            Center(
              child: Text(
                'Silver Honor',
                style: TextStyles.titleBig.copyWith(
                  color: AppColors.colorffffffff,
                ),
              ),
            ),
            const Gap(16),
            SizedBox(
              height: 410,
              child: _buildListContent(),
            ),
            const Gap(14),
            Container(
              color: AppColors.colorff202020op80,
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
              child: CustomButton(
                text: 'Send a silver honor',
                onTap: () =>
                    _showSilverHonorComposerDialog(context, currentPost),
                backgroundColor: AppColors.colorff6D6D6Dop35,
                borderRadius: 8,
                border: Border.all(
                  color: AppColors.colorff656565op25,
                  width: 0.8,
                ),
                textStyle: TextStyles.titleTag.copyWith(
                  color: AppColors.colorffffffff,
                ),
                suffixIcon: Assets.icons.silverCoin.svg(width: 24, height: 24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SilverHonorListItem extends StatelessWidget {
  const _SilverHonorListItem({required this.item});

  final SealResponseEntity item;

  @override
  Widget build(BuildContext context) {
    final displayName = item.user.fullName.trim().isNotEmpty
        ? item.user.fullName
        : item.user.username;
    final rankLine = _buildSilverHonorRankLine(
      item.user.rank,
      item.user.rankSubLevel,
    );
    final message = item.comment.trim().isNotEmpty
        ? item.comment.trim()
        : 'Sent a silver honor.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (item.user.profilePicUrl.trim().isNotEmpty)
                CustomNetworkImage(
                  imageUrl: item.user.profilePicUrl.trim(),
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(8),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.colorff3F3F40,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              Positioned(
                right: -6,
                bottom: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF232324),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Assets.icons.silverCoin.svg(
                    width: 14,
                    height: 14,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyles.titleTag.copyWith(
                          color: AppColors.colorffE5E5E5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.colorff2A2A2B,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.colorff3F3F40,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Assets.icons.silverCoin.svg(width: 12, height: 12),
                          const Gap(4),
                          Text(
                            item.amount.toString(),
                            style: TextStyles.titleTag.copyWith(
                              color: AppColors.colorffE5E5E5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(4),
                Text(
                  rankLine,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorff74afe3,
                  ),
                ),
                const Gap(8),
                Text(
                  message,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffE5E5E5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SilverHonorComposerDialog extends StatefulWidget {
  const _SilverHonorComposerDialog({
    required this.bloc,
    required this.postId,
    required this.currentSealCount,
    required this.sheetContext,
  });

  final HomeBloc bloc;
  final String postId;
  final int currentSealCount;
  final BuildContext sheetContext;

  @override
  State<_SilverHonorComposerDialog> createState() =>
      _SilverHonorComposerDialogState();
}

class _SilverHonorComposerDialogState
    extends State<_SilverHonorComposerDialog> {
  static const int _maxMessageLength = 500;

  late final TextEditingController _messageController;
  bool _isSending = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController()..addListener(_handleChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (_submitError == null) {
      setState(() {});
      return;
    }

    setState(() {
      _submitError = null;
    });
  }

  void _showSuccessDialog() {
    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.sheetContext.mounted) return;

      showDialog<void>(
        context: widget.sheetContext,
        useSafeArea: false,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.50),
        builder: (_) => _SilverHonorSuccessDialog(
          sheetContext: widget.sheetContext,
        ),
      );
    });
  }

  Future<void> _handleSend() async {
    final trimmedMessage = _messageController.text.trim();
    if (trimmedMessage.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _submitError = null;
    });

    final result = await widget.bloc.sendPostSealDirect(
      widget.postId,
      SendPostSealRequest(amount: 1, comment: trimmedMessage),
    );

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isSending = false;
          _submitError = error.message;
        });
      },
      (_) {
        setState(() {
          _isSending = false;
        });
        _showSuccessDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = _messageController.text;
    final canSend = message.trim().isNotEmpty && !_isSending;
    final currentLength = message.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: GlassContainer(
              borderRadius: 18,
              blurSigma: 10,
              backgroundColor: AppColors.colorff202020.withValues(alpha: 0.20),
              borderColor: Colors.white.withValues(alpha: 0.12),
              borderWidth: 1,
              whiteGlowColor: Colors.white.withValues(alpha: 0.10),
              whiteGlowBlurRadius: 12,
              whiteGlowOffset: const Offset(0, -3),
              dropShadowColor: Colors.black.withValues(alpha: 0.45),
              dropShadowBlurRadius: 28,
              dropShadowOffset: const Offset(0, 10),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const SilverBalanceChip.live(),
                    ),
                    const Gap(16),
                    Text(
                      'What would you like to convey along with the honor?',
                      textAlign: TextAlign.center,
                      style: TextStyles.titleMain.copyWith(
                        color: AppColors.textBrand,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const Gap(16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Assets.icons.silverCoin.svg(width: 22, height: 22),
                        const Gap(8),
                        Text(
                          '1',
                          style: TextStyles.titleTag.copyWith(
                            color: AppColors.colorffffffff,
                          ),
                        ),
                      ],
                    ),
                    const Gap(18),
                    if (_submitError != null && _submitError!.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _submitError!,
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFFE5484D),
                          ),
                        ),
                      ),
                      const Gap(12),
                    ],
                    CustomTextField(
                      controller: _messageController,
                      labelText: 'Text Area',
                      hintText: 'Text Area',
                      showLabel: false,
                      height: 176,
                      minLines: null,
                      maxLines: null,
                      maxLength: _maxMessageLength,
                      expands: true,
                      textCapitalization: TextCapitalization.sentences,
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: AppColors.colorffffffff,
                      ),
                      hintStyle: TextStyles.bodyMain.copyWith(
                        color: AppColors.colorffffffff.withValues(alpha: 0.62),
                      ),
                      contentPadding: EdgeInsets.zero,
                      containerPadding:
                          const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      backgroundColor: Colors.black.withValues(alpha: 0.12),
                      customBorder: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                      borderRadius: 12,
                      footer: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLength/$_maxMessageLength',
                          style: TextStyles.titleTag.copyWith(
                            color:
                                AppColors.colorffffffff.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                    const Gap(16),
                    CustomButton(
                      text: _isSending ? 'Sending...' : 'Send',
                      onTap: _handleSend,
                      isDisabled: !canSend,
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const Gap(10),
                    CustomButton(
                      text: 'Cancel',
                      onTap: () => Navigator.of(context).pop(),
                      backgroundColor: const Color(0xFF303030),
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SilverHonorSuccessDialog extends StatelessWidget {
  const _SilverHonorSuccessDialog({
    required this.sheetContext,
  });

  final BuildContext sheetContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GlassContainer(
        borderRadius: 0,
        blurSigma: 18,
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.20),
        borderWidth: 0,
        enableWhiteGlow: false,
        enableDropShadow: false,
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
            child: Column(
              children: [
                const Spacer(),
                Assets.icons.checkedCircle.svg(width: 110, height: 110),
                const Gap(30),
                Text(
                  'Thank you!',
                  style: TextStyles.titleMain.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: AppColors.textBrand,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    'Your silver honor has been sent successfully.',
                    style: TextStyles.bodyMain.copyWith(
                      color: const Color(0xFFBABABA),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                CustomOutlinedButton(
                  text: 'Great !',
                  width: double.infinity,
                  borderRadius: 12,
                  borderColor: Colors.white.withValues(alpha: 0.55),
                  backgroundColor: Colors.transparent,
                  textStyle: TextStyles.titleMain.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    color: AppColors.textBrand,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _buildSilverHonorRankLine(String rank, String rankSubLevel) {
  final rankParts = [
    rank.trim(),
    rankSubLevel.trim(),
  ].where((part) => part.isNotEmpty).toList();
  if (rankParts.isEmpty) {
    return 'Silver Honor';
  }
  return rankParts.join(' / ');
}
