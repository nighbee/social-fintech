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

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 30,
              bottom: 200,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 16, 57, 21),
                  ),
                  height: 250,
                  width: 300,
                ),
              ),
            ),
            Padding(
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
                        top: -6,
                        right: -20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/Big_golden_coin.png',
                                width: 14,
                                height: 14,
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
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Ok',
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: 8,
                    backgroundColor: const Color(0xFF121418),
                    border: Border.all(color: Colors.white24),
                    textStyle: TextStyles.bodyMain.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
