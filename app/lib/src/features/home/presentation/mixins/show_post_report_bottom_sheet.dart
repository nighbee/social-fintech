import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/action_bottom_sheet.dart';
import 'package:app/src/core/widgets/extensions/build_context_ext.dart';
import 'package:app/src/features/home/domain/requests/post_id_request.dart';
import 'package:app/src/features/home/domain/requests/report_post_request.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum PostReportReason {
  spamOrScam(label: 'Spam or scam', apiReason: 'spam'),
  hateHarassment(label: 'Hate, harassment', apiReason: 'hate'),
  nuditySexualContent(label: 'Nudity or sexual content', apiReason: 'nudity'),
  violence(label: 'Violence', apiReason: 'violence'),
  illegalContent(label: 'Illegal content', apiReason: 'illegal'),
  gamblingPromotion(label: 'Gambling promotion', apiReason: 'gambling'),
  copyrightViolation(label: 'Copyright violation', apiReason: 'copyright'),
  fakeAccount(label: 'Fake account', apiReason: 'fake_account'),
  manipulationOfHonor(
      label: 'Manipulation of Honor', apiReason: 'manipulation');

  const PostReportReason({required this.label, required this.apiReason});
  final String label;
  final String apiReason;
}

mixin ShowPostReportBottomSheet {
  void showPostReportBottomSheet(
    BuildContext context, {
    required HomeBloc bloc,
    required String postId,
    required String authorId,
    required String username,
    VoidCallback? onReported,
  }) {
    context.showRoundedModalBottomSheet(
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      maxHeightFactor: 0.9,
      child: ActionBottomSheet(
        backgroundColor: const Color(0xFF202020),
        backgroundOpacity: 0.2,
        enableGlassEffect: true,
        enableDropShadow: false,
        showDivider: false,
        child: _PostReportFlowSheet(
          bloc: bloc,
          postId: postId,
          authorId: authorId,
          username: username,
          onReported: onReported,
        ),
      ),
    );
  }
}

class _PostReportFlowSheet extends StatefulWidget {
  const _PostReportFlowSheet({
    required this.bloc,
    required this.postId,
    required this.authorId,
    required this.username,
    this.onReported,
  });

  final HomeBloc bloc;
  final String postId;
  final String authorId;
  final String username;
  final VoidCallback? onReported;

  @override
  State<_PostReportFlowSheet> createState() => _PostReportFlowSheetState();
}

class _PostReportFlowSheetState extends State<_PostReportFlowSheet> {
  final IProfileRepository _profileRepository = getIt<IProfileRepository>(
    instanceName: 'ProfileRepositoryImpl',
  );
  PostReportReason? _selectedReason;
  bool _isSubmitting = false;
  String? _errorText;

  bool _isDuplicateReportError(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized == 'duplicate_report' ||
        normalized.contains('duplicate report') ||
        normalized.contains('already reported');
  }

  Future<void> _submitReport(PostReportReason reason) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await widget.bloc.reportPostDirect(
      PostIdRequest(postId: widget.postId),
      ReportPostRequest(reason: reason.apiReason),
    );

    if (!mounted) {
      return;
    }

    result.fold(
      (error) {
        if (_isDuplicateReportError(error.message)) {
          setState(() {
            _selectedReason = reason;
            _isSubmitting = false;
            _errorText = null;
          });
          return;
        }

        setState(() {
          _isSubmitting = false;
          _errorText = error.message;
        });
      },
      (_) {
        setState(() {
          _selectedReason = reason;
          _isSubmitting = false;
          _errorText = null;
        });
        widget.onReported?.call();
      },
    );
  }

  Future<void> _blockAuthor() async {
    await _runProfileAction(
      action: _profileRepository.blockUser,
    );
  }

  Future<void> _restrictAuthor() async {
    await _runProfileAction(
      action: _profileRepository.restrictUser,
    );
  }

  Future<void> _runProfileAction({
    required Future<dynamic> Function(UserIdRequest request) action,
  }) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await action(UserIdRequest(userId: widget.authorId));

    if (!mounted) {
      return;
    }

    result.fold(
      (error) {
        setState(() {
          _isSubmitting = false;
          _errorText = error.message;
        });
      },
      (_) {
        widget.bloc.add(const HomeEvent.loadPosts());
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop();
      },
    );
  }

  void _openCommunityStandards() {
    context.pushNamed(RouteNames.profileTermsConditions);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedReason == null) {
      return _PostReportReasonSheet(
        isSubmitting: _isSubmitting,
        errorText: _errorText,
        onReasonTap: _submitReport,
      );
    }

    return _PostReportResultSheet(
      username: widget.username,
      errorText: _errorText,
      isSubmitting: _isSubmitting,
      onBlockTap: _blockAuthor,
      onRestrictTap: _restrictAuthor,
      onLearnTap: _openCommunityStandards,
      onDoneTap: () => Navigator.of(context).pop(),
    );
  }
}

class _PostReportReasonSheet extends StatelessWidget {
  const _PostReportReasonSheet({
    required this.onReasonTap,
    required this.isSubmitting,
    this.errorText,
  });

  final Future<void> Function(PostReportReason reason) onReasonTap;
  final bool isSubmitting;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Why are you reporting this post?',
              textAlign: TextAlign.center,
              style: TextStyles.titleHeadline.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "Your report is anonymous. If someone is in\nimmediate danger, call the local emergency services\n- don't wait.",
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFF888888),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF5F1D1D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9A4747), width: 1),
              ),
              child: Text(
                errorText!,
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFFFFE0E0),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...PostReportReason.values.map(
            (reason) => _ReportReasonRow(
              label: reason.label,
              onTap: isSubmitting ? null : () => onReasonTap(reason),
            ),
          ),
          if (isSubmitting) ...[
            const SizedBox(height: 10),
            const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ],
      ),
    );
  }
}

class _ReportReasonRow extends StatelessWidget {
  const _ReportReasonRow({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyles.bodyLarge.copyWith(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  height: 21 / 17,
                  letterSpacing: 0,
                  color: const Color(0xFFE6E6E6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF6D6D6D),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostReportResultSheet extends StatelessWidget {
  const _PostReportResultSheet({
    required this.username,
    required this.errorText,
    required this.isSubmitting,
    required this.onBlockTap,
    required this.onRestrictTap,
    required this.onLearnTap,
    required this.onDoneTap,
  });

  final String username;
  final String? errorText;
  final bool isSubmitting;
  final Future<void> Function() onBlockTap;
  final Future<void> Function() onRestrictTap;
  final VoidCallback onLearnTap;
  final VoidCallback onDoneTap;

  @override
  Widget build(BuildContext context) {
    final displayName = username.trim().isEmpty ? 'this account' : username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Thanks for your feedback !',
              style: TextStyles.titleHeadline.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'We use these reports to show you less of\nthis kind of content in the future.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFF888888),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Others steps you can take',
            style: TextStyles.titleTag.copyWith(
              color: const Color(0xFFE6E6E6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _ReportActionRow(
            icon: Assets.icons.blocked.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFCB5B5B),
                BlendMode.srcIn,
              ),
            ),
            title: 'Block $displayName',
            titleColor: const Color(0xFFCB5B5B),
            onTap: isSubmitting ? null : onBlockTap,
          ),
          _ReportActionRow(
            icon: Assets.icons.eyeClosed.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFE5E5E5),
                BlendMode.srcIn,
              ),
            ),
            title: 'Restrict $displayName',
            onTap: isSubmitting ? null : onRestrictTap,
          ),
          _ReportActionRow(
            icon: Assets.icons.noPeople.svg(
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFFE5E5E5),
                BlendMode.srcIn,
              ),
            ),
            title: 'Learn about our Community Standards',
            onTap: isSubmitting ? null : () async => onLearnTap(),
          ),
          if (errorText != null && errorText!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF5F1D1D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF9A4747), width: 1),
              ),
              child: Text(
                errorText!,
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFFFFE0E0),
                ),
              ),
            ),
          ],
          if (isSubmitting) ...[
            const SizedBox(height: 10),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isSubmitting ? null : onDoneTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyles.titleTag.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportActionRow extends StatelessWidget {
  const _ReportActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor = const Color(0xFFE6E6E6),
  });

  final Widget icon;
  final String title;
  final Future<void> Function()? onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap == null ? null : () => onTap!.call(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyles.bodyLarge.copyWith(
                  fontFamily: 'Lora',
                  fontSize: 17,
                  height: 21 / 17,
                  letterSpacing: 0,
                  color: titleColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF6D6D6D),
            ),
          ],
        ),
      ),
    );
  }
}
