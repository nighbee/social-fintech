import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/home/domain/entities/post_response_entity.dart';
import 'package:app/src/features/home/domain/requests/update_post_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

mixin ShowPublicationOwnerActionsBottomSheet {
  Future<bool> _showDeleteConfirmSheet(BuildContext context) async {
    final result = await context.showRoundedModalBottomSheet<bool>(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.34,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.2,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Gap(18),
                Text(
                  'Delete post?',
                  style: TextStyles.titleMain.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(10),
                Text(
                  'This post will be removed from your profile and feed.',
                  textAlign: TextAlign.center,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Gap(18),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: 'Cancel',
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: _SheetButton(
                        label: 'Delete',
                        isDestructive: true,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> showPublicationOwnerActionsBottomSheet(
    BuildContext context, {
    required HomeBloc bloc,
    required PostResponseEntity post,
    required VoidCallback onPostDeleted,
  }) async {
    await context.showRoundedModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      maxHeightFactor: 0.42,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.1,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: Stack(
          children: [
            const Positioned.fill(child: _OwnerSheetVisualLayer()),
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Gap(12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Gap(12),
                  _OwnerActionTile(
                    label: 'Delete',
                    isDestructive: true,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sheetNavigator = Navigator.of(context);

                      if (sheetNavigator.canPop()) {
                        sheetNavigator.pop();
                      }
                      final confirmed = await _showDeleteConfirmSheet(context);
                      if (confirmed != true) return;

                      final result = await bloc.deletePostDirect(post.postId);
                      result.fold(
                        (e) {
                          messenger?.showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        },
                        (_) => onPostDeleted(),
                      );
                    },
                  ),
                  _OwnerActionTile(
                    label:
                        post.hideLikesCount ? 'Show like count' : 'Hide like count',
                    onTap: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sheetNavigator = Navigator.of(context);
                      if (sheetNavigator.canPop()) {
                        sheetNavigator.pop();
                      }
                      final next = !post.hideLikesCount;
                      final result = await bloc.updatePostDirect(
                        post.postId,
                        UpdatePostRequest(hideLikesCount: next),
                      );
                      result.fold(
                        (e) {
                          messenger?.showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        },
                        (_) {},
                      );
                    },
                  ),
                  _OwnerActionTile(
                    label: post.permissions.canComment
                        ? 'Turn off commenting'
                        : 'Allow comments',
                    onTap: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final sheetNavigator = Navigator.of(context);
                      if (sheetNavigator.canPop()) {
                        sheetNavigator.pop();
                      }
                      final nextPermission =
                          post.permissions.canComment ? 'NO_ONE' : 'ANYONE';
                      final result = await bloc.updatePostDirect(
                        post.postId,
                        UpdatePostRequest(commentPermission: nextPermission),
                      );
                      result.fold(
                        (e) {
                          messenger?.showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        },
                        (_) {},
                      );
                    },
                  ),
                  const Gap(14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerSheetVisualLayer extends StatelessWidget {
  const _OwnerSheetVisualLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF5B2A42).withValues(alpha: 0.12),
              const Color(0xFF24252D).withValues(alpha: 0.08),
              const Color(0xFF24252D).withValues(alpha: 0.08),
              const Color(0xFF7C2A4B).withValues(alpha: 0.12),
            ],
            stops: const [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
}

class _OwnerActionTile extends StatelessWidget {
  const _OwnerActionTile({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Center(
            child: Text(
              label,
              style: TextStyles.titleHeadline.copyWith(
                color: isDestructive
                    ? const Color(0xFFD93337)
                    : Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyles.titleHeadline.copyWith(
              color: isDestructive
                  ? const Color(0xFFFF5C5C)
                  : const Color(0xFFF3F4F6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
