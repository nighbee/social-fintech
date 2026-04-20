import 'dart:ui';

import 'package:app/gen/fonts.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/features/map/domain/entities/map_task_application_entity.dart';
import 'package:flutter/material.dart';

class MapDialogService {
  bool _isConfirmDialogOpen = false;
  String? _lastConfirmPromptApplicationId;
  bool _isRejectedDialogOpen = false;
  String? _lastHandledRejectedApplicationId;

  void resetRejectedHandledId() {
    _lastHandledRejectedApplicationId = null;
  }

  Future<void> showCreatorNoResponsesDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: _popupDecoration(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 38,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No one responded to your request',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unfortunately, there have been no responses to\nthe request in the last 24 hours.',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 14),
                    CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: 6,
                      backgroundColor: Colors.transparent,
                      border: Border.all(color: Colors.white54),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> showInitialLocationOnboardingDialog(BuildContext context) async {
    const descriptionText =
        'We use your location solely to determine your region. Your exact '
        'address is always kept private and is never published. You can '
        'choose to opt out and hide yourself from the map at any time in '
        'your settings.';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Align(
          alignment: const Alignment(0, 0.18),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 25),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(30, 32, 35, 0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0x00000000),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 34,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'How the map works ?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: FontFamily.lora,
                            fontSize: 40 / 2.5,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 17.5),
                          child: Text(
                            descriptionText,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontFamily: FontFamily.lora,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 20 / 14,
                              color: Color(0xFF9D9D9D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        CustomButton(
                          text: 'Confirm',
                          onTap: () => Navigator.of(dialogContext).pop(true),
                          borderRadius: 8,
                          backgroundColor: const Color(0xFFE5E5E5),
                          textStyle: const TextStyle(
                            fontFamily: FontFamily.lora,
                            fontSize: 36 / 2.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: Color(0xFF1B1B1B),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        const SizedBox(height: 10),
                        CustomButton(
                          text: 'Not now',
                          onTap: () => Navigator.of(dialogContext).pop(false),
                          borderRadius: 8,
                          backgroundColor: Colors.transparent,
                          border: Border.all(color: Colors.white38),
                          textStyle: const TextStyle(
                            fontFamily: FontFamily.lora,
                            fontSize: 36 / 2.5,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            color: Color(0xFFB8B8B8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> showExecutorCancelConfirmDialog({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: _popupDecoration(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you sure you want to cancel this request?',
                      textAlign: TextAlign.center,
                      style:
                          TextStyles.bodyMain.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Confirm',
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              onConfirm();
                            },
                            borderRadius: 6,
                            backgroundColor: const Color(0xFFE5E5E5),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CustomButton(
                            text: 'Cancel',
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: 6,
                            backgroundColor: Colors.transparent,
                            border: Border.all(color: Colors.white38),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
      },
    );
  }

  Future<void> showExecutorCanceledDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: _popupDecoration(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Request canceled',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyLarge.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your request has been canceled.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyles.bodyMain.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: 6,
                      backgroundColor: const Color(0xFFE5E5E5),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> tryShowCreatorConfirmDialog({
    required BuildContext context,
    required String? selectedApplicationId,
    required List<MapTaskApplicationEntity> applications,
    required void Function(MapTaskApplicationEntity selected) onConfirm,
  }) async {
    if (_isConfirmDialogOpen) {
      return;
    }

    MapTaskApplicationEntity? selectedApplication;
    if (selectedApplicationId != null) {
      for (final app in applications) {
        final normalizedStatus = app.status.trim().toLowerCase();
        if (app.id == selectedApplicationId &&
            normalizedStatus == 'code_verified') {
          selectedApplication = app;
          break;
        }
      }
    }

    selectedApplication ??= applications
        .cast<MapTaskApplicationEntity?>()
        .firstWhere(
          (app) =>
              app != null && app.status.trim().toLowerCase() == 'code_verified',
          orElse: () => null,
        );

    if (selectedApplication == null) {
      return;
    }
    if (_lastConfirmPromptApplicationId == selectedApplication.id) {
      return;
    }

    _lastConfirmPromptApplicationId = selectedApplication.id;
    _isConfirmDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final helperName =
            selectedApplication!.applicantUsername.trim().isNotEmpty
                ? selectedApplication.applicantUsername.trim()
                : _compactApplicant(selectedApplication.applicantId);
        final displayHelperName = helperName
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final helperAvatarUrl = selectedApplication.applicantAvatarUrl.trim();
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E5560).withValues(alpha: 0.48),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x42FFFFFF),
                      Color(0x1CFFFFFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF303237),
                      backgroundImage: helperAvatarUrl.isEmpty
                          ? null
                          : NetworkImage(helperAvatarUrl),
                      child: helperAvatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 22,
                              color: Colors.white70,
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Did ${displayHelperName.isEmpty ? helperName : displayHelperName} help you complete the\ntask?',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Yes',
                            onTap: () {
                              onConfirm(selectedApplication!);
                              Navigator.of(dialogContext).pop();
                            },
                            borderRadius: 10,
                            backgroundColor: const Color(0xFFE5E5E8),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'No',
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: 10,
                            backgroundColor: Colors.transparent,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.62),
                            ),
                            textStyle: TextStyles.bodyMain.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontWeight: FontWeight.w500,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
      },
    );

    _isConfirmDialogOpen = false;
  }

  Future<void> tryShowExecutorRejectedDialog({
    required BuildContext context,
    required String applicationId,
    required bool executorCompletionShown,
    required String executorTaskStatus,
    required String executorCreatorName,
  }) async {
    if (_isRejectedDialogOpen || executorCompletionShown) {
      return;
    }
    if (applicationId.isEmpty || executorTaskStatus != 'rejected') {
      return;
    }
    if (_lastHandledRejectedApplicationId == applicationId) {
      return;
    }

    _lastHandledRejectedApplicationId = applicationId;
    _isRejectedDialogOpen = true;

    final creatorName = executorCreatorName.trim().isEmpty
        ? 'Creator'
        : executorCreatorName.trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: _popupDecoration(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$creatorName rejected your request.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyles.bodyMain.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: 6,
                      backgroundColor: const Color(0xFFE5E5E5),
                      textStyle: TextStyles.bodyMain.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _isRejectedDialogOpen = false;
  }

  String _compactApplicant(String applicantId) {
    if (applicantId.trim().isEmpty) {
      return 'User';
    }
    final trimmed = applicantId.trim();
    if (trimmed.length <= 18) {
      return trimmed;
    }
    return trimmed.substring(0, 18);
  }

  BoxDecoration _popupDecoration(double radius) {
    return BoxDecoration(
      color: const Color(0xFF565A63).withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(radius),
      border:
          Border.all(color: const Color(0xFF8B9099).withValues(alpha: 0.62)),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
