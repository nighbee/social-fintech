part of '../../pages/allies_page.dart';

class _SortButton extends StatelessWidget {
  const _SortButton({required this.selectedSort, required this.onTap});

  final String selectedSort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sort by',
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                    color: AppColors.colorffE5E5E5,
                  ),
                ),
                const Gap(4),
                Text(
                  selectedSort,
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 20 / 14,
                    color: AppColors.colorffE5E5E5,
                  ),
                ),
                const Gap(6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.colorffE5E5E5,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
