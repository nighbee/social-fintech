part of '../../pages/allies_page.dart';

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomTextField(
        controller: controller,
        labelText: 'Search',
        prefixIcon: Assets.icons.search.svg(),
        showBorder: false,
        backgroundColor: const Color(0xFF333333),
        height: 54,
      ),
    );
  }
}
