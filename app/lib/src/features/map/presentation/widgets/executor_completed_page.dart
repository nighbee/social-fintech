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
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 6),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFF2A3341),
                                backgroundImage: avatarUrl.isEmpty
                                    ? null
                                    : NetworkImage(avatarUrl),
                                child: avatarUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 44,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                              Positioned(
                                top: -4,
                                right: -6,
                                child: SizedBox(
                                  height: 30,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x66343B45),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: const Color(0xFFCACACA),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/images/Big_golden_coin.png',
                                          width: 22,
                                          height: 22,
                                          fit: BoxFit.contain,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '1',
                                          style: TextStyles.bodyMain.copyWith(
                                            fontFamily: FontFamily.lora,
                                            color: const Color(0xFFCACACA),
                                            fontSize: 20,
                                            height: 24 / 20,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                fontFamily: FontFamily.lora,
                                color: const Color(0xFFCACACA),
                                fontSize: 33 / 2,
                                height: 20 / 16.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            'Congratulations!',
                            style: TextStyles.titleTag.copyWith(
                              fontFamily: FontFamily.lora,
                              color: const Color(0xFFF2F2F2),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'ve successfully completed the task\nand moved up in rank. Keep going!',
                            textAlign: TextAlign.center,
                            style: TextStyles.bodyMain.copyWith(
                              fontFamily: FontFamily.lora,
                              color: const Color(0xFFCACACA),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 20 / 14,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: CustomButton(
                      text: 'Ok',
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: 6,
                      backgroundColor: Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFFCACACA),
                        width: 0.5,
                      ),
                      textStyle: TextStyles.bodyMain.copyWith(
                        fontFamily: FontFamily.lora,
                        color: const Color(0xFFCACACA),
                        fontSize: 20,
                        height: 24 / 20,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    ),
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
