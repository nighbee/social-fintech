part of '../../pages/allies_page.dart';


class _SortButton extends StatelessWidget {
  const _SortButton({required this.selectedSort, required this.onTap});

  final String selectedSort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Sort by',
            style: TextStyles.bodyMain.copyWith(color: const Color(0xFF6D6D6D)),
          ),
          const Gap(8),
          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedSort,
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
