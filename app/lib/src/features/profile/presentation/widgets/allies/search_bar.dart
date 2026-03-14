part of '../../pages/allies_page.dart';

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: CustomTextField(
        controller: controller,
        labelText: 'Search',
        hintText: 'Search',
        onChanged: onChanged,
        prefixIcon: Assets.icons.search.svg(
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            AppColors.colorffffffff,
            BlendMode.srcIn,
          ),
        ),
        showBorder: false,
        showLabel: false,
        backgroundColor: const Color(0xFF1E1E1E),
        height: 48,
        borderRadius: 10,
        containerPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        contentPadding: EdgeInsets.zero,
        textStyle: TextStyles.bodyLarge.copyWith(
          color: AppColors.colorffE5E5E5,
        ),
        hintStyle: TextStyles.bodyLarge.copyWith(
          color: const Color(0xFFBABABA),
        ),
      ),
    );
  }
}
