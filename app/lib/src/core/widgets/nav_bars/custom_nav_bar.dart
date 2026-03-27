import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';

class CustomNavBar extends StatelessWidget {
  const CustomNavBar({required this.currentTab, super.key});

  final String currentTab;

  @override
  Widget build(BuildContext context) {
    final List<String> paths = [
      RoutePaths.home,
      RoutePaths.map,
      RoutePaths.rating,
      RoutePaths.chats,
      RoutePaths.profile,
    ];

    final List<String> titles = [
      'Home',
      'Map',
      'Rating',
      'Chats',
      'Profile',
    ];
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final currentIndex = paths.indexOf(currentTab).clamp(0, paths.length - 1);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        color: AppColors.colorff000000,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: safeBottom > 0 ? safeBottom : 10,
        ),
        child: Row(
          children: List<Widget>.generate(paths.length, (index) {
            final bool isSelected = index == currentIndex;
            return Expanded(
              child: _NavBarItem(
                title: titles[index],
                isSelected: isSelected,
                icon: _buildIcon(index, isSelected),
                onTap: () => context.go(paths[index]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildIcon(int index, bool isSelected) {
    final color = isSelected ? Colors.white : AppColors.textGray2;
    final filter = ColorFilter.mode(color, BlendMode.srcIn);
    switch (index) {
      case 0:
        return Assets.icons.feedIcon
            .svg(width: 20, height: 20, colorFilter: filter);
      case 1:
        return Assets.icons.mapIcon
            .svg(width: 20, height: 20, colorFilter: filter);
      case 2:
        return Assets.icons.ratingIcon
            .svg(width: 20, height: 20, colorFilter: filter);
      case 3:
        return Assets.icons.chatsIcon
            .svg(width: 20, height: 20, colorFilter: filter);
      case 4:
        return Assets.icons.profileIcon
            .svg(width: 20, height: 20, colorFilter: filter);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.title,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            icon,
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyles.bodyMain.copyWith(
                color: isSelected ? Colors.white : AppColors.textGray2,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
