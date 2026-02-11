import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.showLeading = true,
    this.backgroundColor,
    this.title,
    this.leadingIconSize = 20,
    this.onLeadingTap,
    this.actions,
    this.centerTitle = true,
  });

  final bool showLeading;
  final Color? backgroundColor;
  final String? title;
  final double leadingIconSize;
  final VoidCallback? onLeadingTap;
  final List<Widget>? actions;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? context.theme.mainBackground,
      surfaceTintColor: backgroundColor ?? context.theme.mainBackground,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,

      leading: showLeading
          ? GestureDetector(
              onTap: onLeadingTap ?? () => context.pop(),
              child: Center(
                child: Assets.icons.arrowBack.svg(
                  width: leadingIconSize,
                  height: leadingIconSize,
                ),
              ),
            )
          : null,
      title: title != null
          ? Text(
              title!,
              style: TextStyles.titleMain.copyWith(color: Colors.white),
            )
          : null,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
