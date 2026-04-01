import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/core/widgets/silver_balance_chip.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/entities/seal_response_entity.dart';
import 'package:app/src/features/home/domain/requests/get_post_seals_request.dart';
import 'package:app/src/features/home/domain/requests/send_post_seal_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/honor_compose_surface.dart';
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
        enableDropShadow: false,
        backgroundOpacity: 1,
        backgroundColor: const Color(0xFF161616),
        child: PostSilverHonorBottomSheet(
          bloc: bloc,
          post: post,
          hostContext: context,
        ),
      ),
    );
  }
}

class PostSilverHonorBottomSheet extends StatefulWidget {
  const PostSilverHonorBottomSheet({
    required this.bloc,
    required this.post,
    required this.hostContext,
    super.key,
  });

  final HomeBloc bloc;
  final PostResponseEntity post;
  final BuildContext hostContext;

  @override
  State<PostSilverHonorBottomSheet> createState() =>
      _PostSilverHonorBottomSheetState();
}

class _PostSilverHonorBottomSheetState
    extends State<PostSilverHonorBottomSheet> {
  bool _isLoading = true;
  String? _loadError;
  List<SealResponseEntity> _seals = const [];
  bool _isBalanceRefreshing = false;
  int? _availableSilverCountOverride;

  int _resolveAvailableSilverCount(HomeViewModel viewModel) {
    return _availableSilverCountOverride ?? viewModel.storeSummary.silverHonorsCount;
  }

  bool _hasAvailableSilver(HomeViewModel viewModel) {
    return _resolveAvailableSilverCount(viewModel) > 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSeals();
      _refreshAvailableSilver();
    });
  }

  Future<void> _refreshAvailableSilver() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isBalanceRefreshing = true;
    });

    final result = await widget.bloc.getStoreSummaryDirect();
    if (!mounted) {
      return;
    }

    result.fold(
      (_) {
        setState(() {
          _isBalanceRefreshing = false;
        });
      },
      (storeSummary) {
        setState(() {
          _availableSilverCountOverride = storeSummary.silverHonorsCount;
          _isBalanceRefreshing = false;
        });
      },
    );
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
  ) async {
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!widget.hostContext.mounted) return;

    final sent = await showDialog<bool>(
      context: widget.hostContext,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (_) {
        return _SilverHonorComposerDialog(
          bloc: widget.bloc,
          postId: currentPost.postId,
          currentSealCount: currentPost.metrics.silvers,
        );
      },
    );

    if (sent == true) {
      // The list sheet is intentionally closed before showing composer.
      // Keep flow focused on composing/sending as in the design.
      return;
    }
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
        final hasAvailableSilver = _hasAvailableSilver(viewModel);

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
              color: const Color(0xFF161616),
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
              child: CustomButton(
                text: 'Send a silver honor',
                onTap: !_isBalanceRefreshing && hasAvailableSilver
                    ? () => _showSilverHonorComposerDialog(context, currentPost)
                    : () {},
                isDisabled: _isBalanceRefreshing || !hasAvailableSilver,
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
            if (_isBalanceRefreshing)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Checking silver balance...',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffE5E5E5.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              )
            else if (!hasAvailableSilver)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'You have 0 silver honors. Refill in Store to send one.',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffE5E5E5.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SilverHonorListItem extends StatefulWidget {
  const _SilverHonorListItem({required this.item});

  final SealResponseEntity item;

  @override
  State<_SilverHonorListItem> createState() => _SilverHonorListItemState();
}

class _SilverHonorListItemState extends State<_SilverHonorListItem> {
  bool _expanded = false;

  static const int _toggleThreshold = 80;

  bool _shouldToggle(String message) => message.length > _toggleThreshold;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
                  maxLines: _expanded ? null : 2,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                if (_shouldToggle(message)) ...[
                  const Gap(4),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'hide' : 'see more',
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.colorffE5E5E5.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
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
  });

  final HomeBloc bloc;
  final String postId;
  final int currentSealCount;

  @override
  State<_SilverHonorComposerDialog> createState() =>
      _SilverHonorComposerDialogState();
}

class _SilverHonorComposerDialogState
    extends State<_SilverHonorComposerDialog> {
  static const int _maxMessageLength = 500;

  late final TextEditingController _messageController;
  bool _isSending = false;
  bool _isBalanceLoading = true;
  int _availableSilverCount = 0;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController()..addListener(_handleChanged);
    _syncBalanceFromState();
    _refreshBalanceFromServer();
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

  void _syncBalanceFromState() {
    final viewModel = widget.bloc.state.maybeWhen(
      loading: (viewModel) => viewModel,
      loaded: (viewModel) => viewModel,
      orElse: HomeViewModel.new,
    );
    _availableSilverCount = viewModel.storeSummary.silverHonorsCount;
    _isBalanceLoading = false;
  }

  Future<void> _refreshBalanceFromServer() async {
    setState(() {
      _isBalanceLoading = true;
    });

    final result = await widget.bloc.getStoreSummaryDirect();
    if (!mounted) return;

    result.fold(
      (_) {
        setState(() {
          _isBalanceLoading = false;
        });
      },
      (storeSummary) {
        setState(() {
          _availableSilverCount = storeSummary.silverHonorsCount;
          _isBalanceLoading = false;
        });
      },
    );
  }

  Future<void> _handleSend() async {
    final trimmedMessage = _messageController.text.trim();
    if (trimmedMessage.isEmpty || _isSending) return;
    if (_isBalanceLoading) {
      setState(() {
        _submitError = 'Checking silver balance. Please wait...';
      });
      return;
    }
    if (_availableSilverCount <= 0) {
      setState(() {
        _submitError = 'You have no silver honors left to send.';
      });
      return;
    }

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
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = _messageController.text;
    final canSend = message.trim().isNotEmpty &&
        !_isSending &&
        !_isBalanceLoading &&
        _availableSilverCount > 0;
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
            child: HonorComposeSurface(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SilverBalanceChip(count: _availableSilverCount),
                    ),
                    if (!_isBalanceLoading && _availableSilverCount <= 0) ...[
                      const Gap(10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'You have 0 silver honors. Refill in Store to continue.',
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFFE5B86B),
                          ),
                        ),
                      ),
                    ],
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
                      backgroundColor: AppColors.backgroundBrandLight,
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: AppColors.textNeutral,
                        fontWeight: FontWeight.w600,
                      ),
                      disabledBackgroundColor:
                          AppColors.backgroundDisabledDefault,
                      disabledTextStyle: TextStyles.bodyMain.copyWith(
                        color: AppColors.textDisabledDefault,
                        fontWeight: FontWeight.w600,
                      ),
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
                      borderRadius: 8,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.backgroundNeutralSecondary,
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
              ),
            ),
          );
        },
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
