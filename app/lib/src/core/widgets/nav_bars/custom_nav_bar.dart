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

    final List<String> titles = ['Home', 'Map', 'Rating', 'Chats', 'Profile'];

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        color: AppColors.blackBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            currentIndex: paths.indexOf(currentTab),
            unselectedItemColor: AppColors.textGray2,
            selectedItemColor: AppColors.blueText1,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: context.theme.textStyles.titleHeadline.copyWith(
              color: AppColors.blueText1,
            ),
            unselectedLabelStyle: context.theme.textStyles.titleHeadline
                .copyWith(color: AppColors.textGray2),
            onTap: (int index) {
              context.go(paths[index]);
            },
            items: titles.asMap().entries.map((entry) {
              final int index = entry.key;
              final title = entry.value;
              final isSelected = index == paths.indexOf(currentTab);

              Widget iconWidget;
              switch (index) {
                case 0:
                  iconWidget = Assets.icons.feedIcon.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? AppColors.blueText1 : AppColors.textGray2,
                      BlendMode.srcIn,
                    ),
                  );
                  break;
                case 1:
                  iconWidget = Assets.icons.mapIcon.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? AppColors.blueText1 : AppColors.textGray2,
                      BlendMode.srcIn,
                    ),
                  );
                  break;
                case 2:
                  iconWidget = Assets.icons.ratingIcon.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? AppColors.blueText1 : AppColors.textGray2,
                      BlendMode.srcIn,
                    ),
                  );
                  break;
                case 3:
                  iconWidget = Assets.icons.chatsIcon.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? AppColors.blueText1 : AppColors.textGray2,
                      BlendMode.srcIn,
                    ),
                  );
                  break;
                case 4:
                  iconWidget = Assets.icons.profileIcon.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isSelected ? AppColors.blueText1 : AppColors.textGray2,
                      BlendMode.srcIn,
                    ),
                  );
                  break;
                default:
                  iconWidget = const SizedBox();
              }

              return BottomNavigationBarItem(
                label: title,
                icon: SizedBox(width: 24, height: 24, child: iconWidget),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
