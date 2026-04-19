part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _ExecutorCompletedPage extends StatelessWidget {
  const _ExecutorCompletedPage();

  @override
  Widget build(BuildContext context) {
    final avatarUrl = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (vm) => vm.profile.avatarUrl,
          loading: (vm) => vm.profile.avatarUrl,
          orElse: () => '',
        );
    final userId = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (vm) => vm.profile.userId,
          loading: (vm) => vm.profile.userId,
          orElse: () => '',
        );
    final displayName = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (vm) => vm.profile.displayName,
          loading: (vm) => vm.profile.displayName,
          orElse: () => '',
        );
    final resolvedName =
        displayName.trim().isNotEmpty ? displayName.trim() : userId.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF12161B),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF12161B),
                    Color(0xFF0A0D12),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0.56),
                    radius: 0.9,
                    colors: [
                      Color(0x4A214D36),
                      Color(0x1A132820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-1.02, 0.08),
                    radius: 1.08,
                    colors: [
                      Color(0x2E1E5A37),
                      Color(0x10122820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(1.02, 0.08),
                    radius: 1.08,
                    colors: [
                      Color(0x2E1E5A37),
                      Color(0x10122820),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.46, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFF2A3341),
                        backgroundImage:
                            avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                        child: avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 44,
                                color: Colors.white70,
                              )
                            : null,
                      ),
                      Positioned(
                        top: -5,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x66343B45),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/Big_golden_coin.png',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '1',
                                style: TextStyles.bodyMain.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (resolvedName.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      resolvedName,
                      style: TextStyles.bodyMain.copyWith(
                        color: const Color(0xFFCACACA),
                        fontSize: 18,
                        height: 1.05,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Congratulations!',
                    style: TextStyles.titleTag.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ve successfully completed the task\nand moved up in rank. Keep going!',
                    textAlign: TextAlign.center,
                    style: TextStyles.bodyMain.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Ok',
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: 8,
                    backgroundColor: Colors.transparent,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    textStyle: TextStyles.bodyMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
