import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/home/presentation/widgets/honor_compose_surface.dart';
import 'package:flutter/material.dart';

Future<void> showProfileBioGlassDialog(
  BuildContext context, {
  required String bio,
}) {
  final text = bio.trim();
  if (text.isEmpty) return Future.value();

  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final maxBodyHeight = MediaQuery.sizeOf(dialogContext).height * 0.58;
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(dialogContext).pop(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: HonorComposeSurface(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxBodyHeight),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {},
                            child: Text(
                              text,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: TextStyles.bodyLarge.copyWith(
                                color: const Color(0xFFE5E5E5),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
