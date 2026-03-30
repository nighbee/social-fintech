import 'dart:ui';

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
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
    if (_isConfirmDialogOpen || selectedApplicationId == null) {
      return;
    }

    MapTaskApplicationEntity? selectedApplication;
    for (final app in applications) {
      if (app.id == selectedApplicationId) {
        selectedApplication = app;
        break;
      }
    }

    if (selectedApplication == null ||
        selectedApplication.status != 'code_verified') {
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
        final helperName = _compactApplicant(selectedApplication!.applicantId);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 26),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 34, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF656565)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Did $helperName help you complete the task?',
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white70,
                            height: 1.35,
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
                                borderRadius: 6,
                                backgroundColor: const Color(0xFFE5E5E5),
                                textStyle: TextStyles.bodyMain.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: CustomButton(
                                text: 'No',
                                onTap: () => Navigator.of(dialogContext).pop(),
                                borderRadius: 6,
                                backgroundColor: Colors.transparent,
                                border: Border.all(color: Colors.white38),
                                textStyle: TextStyles.bodyMain.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -15,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3341),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
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
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF656565)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
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
}
