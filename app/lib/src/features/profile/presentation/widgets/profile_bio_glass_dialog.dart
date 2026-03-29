import 'package:app/gen/assets.gen.dart';
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
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      final maxBodyHeight = MediaQuery.sizeOf(dialogContext).height * 0.58;
      return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: HonorComposeSurface(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Assets.icons.close.svg(
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white70,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxBodyHeight),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      ],
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
