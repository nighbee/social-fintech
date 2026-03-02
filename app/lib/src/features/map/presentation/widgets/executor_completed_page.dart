part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _ExecutorCompletedPage extends StatelessWidget {
  const _ExecutorCompletedPage();

  @override
  Widget build(BuildContext context) {
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
                  Assets.icons.requestClosed.svg(width: 110, height: 110),
                  const SizedBox(height: 14),
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
                    'Your assistance was confirmed.\nYou have received your reward.',
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
