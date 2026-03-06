import 'dart:ui';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/enums/notification_type.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/notification_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

extension SvgRotation on SvgGenImage {
  Widget svgRotated({
    double degrees = 0,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? color,
  }) {
    return Transform.rotate(
      angle: degrees * 3.14159 / 180,
      child: svg(
        width: width,
        height: height,
        fit: fit,
        color: color,
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NotificationsPageContent();
  }
}

class _NotificationsPageContent extends StatefulWidget {
  const _NotificationsPageContent();

  @override
  State<_NotificationsPageContent> createState() =>
      _NotificationsPageContentState();
}

class _NotificationsPageContentState extends State<_NotificationsPageContent> {
  final GlobalKey _actionKey = GlobalKey();
  bool _showMenu = false;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = getIt<HomeBloc>();
      bloc.add(const HomeEvent.loadNotifications());
    });
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _hideMenu() {
    setState(() {
      _showMenu = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        title: 'Notification',
        actions: [
          GestureDetector(
            key: _actionKey,
            onTap: _toggleMenu,
            child: Assets.icons.more.svgRotated(
              width: 24,
              height: 24,
              degrees: 90,
            ),
          ),
          Gap(20),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: BlocBuilder<HomeBloc, HomeState>(
              bloc: getIt<HomeBloc>(),
              builder: (context, state) {
                return state.when(
                  initial: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  loading: (viewModel) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  loadingError: (message) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.colorffa43337,
                        ),
                        const Gap(16),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyles.titleTag,
                        ),
                        const Gap(8),
                        Text(
                          message,
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.colorff838383,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(24),
                        ElevatedButton(
                          onPressed: () {
                            getIt<HomeBloc>().add(
                              const HomeEvent.loadNotifications(),
                            );
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                  loaded: (viewModel) {
                    final selectedType =
                        NotificationType.fromString(_selectedCategory);
                    final notifications = selectedType == NotificationType.all
                        ? viewModel.notifications
                        : viewModel.notifications
                            .where(
                              (notification) =>
                                  notification.notificationType == selectedType,
                            )
                            .toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCategory,
                            style: TextStyles.titleBig.copyWith(
                              color: AppColors.colorffffffff,
                            ),
                          ),
                          Container(),
                          Gap(20),
                          Expanded(
                            child: ListView.separated(
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) => Gap(20),
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                return NotificationItemWidget(
                                  notification: notification,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_showMenu)
            Positioned.fill(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _hideMenu,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    top: 8,
                    right: 38,
                    child: _GlassMenu(
                      onSelectCategory: (category) {
                        setState(() {
                          _selectedCategory = category;
                        });
                        _hideMenu();
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassMenu extends StatelessWidget {
  const _GlassMenu({
    required this.onSelectCategory,
  });

  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MenuItem(
                  title: 'All',
                  onTap: () => onSelectCategory('All'),
                ),
                _MenuItem(
                  title: 'Like',
                  onTap: () => onSelectCategory('Like'),
                ),
                _MenuItem(
                  title: 'Comment',
                  onTap: () => onSelectCategory('Comment'),
                ),
                _MenuItem(
                  title: 'Help',
                  onTap: () => onSelectCategory('Help'),
                ),
                _MenuItem(
                  title: 'Subscriptions',
                  onTap: () => onSelectCategory('Subscriptions'),
                ),
                _MenuItem(
                  title: 'Posts',
                  onTap: () => onSelectCategory('Posts'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            title,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.colorffffffff,
            ),
          ),
        ),
      ),
    );
  }
}
