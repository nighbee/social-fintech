import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';
import 'package:app/src/features/home/presentation/widgets/notification_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:app/src/core/router/router.dart';

enum NotificationFilter { all, recognition, activity, tasks, rank, system }

extension _NotificationFilterLabel on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.recognition:
        return 'Recognition';
      case NotificationFilter.activity:
        return 'Activity';
      case NotificationFilter.tasks:
        return 'Tasks';
      case NotificationFilter.rank:
        return 'Rank';
      case NotificationFilter.system:
        return 'System';
    }
  }

  String? get backendTab {
    switch (this) {
      case NotificationFilter.all:
        return null;
      case NotificationFilter.recognition:
        return 'RECOGNITION';
      case NotificationFilter.activity:
        return 'ACTIVITY';
      case NotificationFilter.tasks:
        return 'TASKS';
      case NotificationFilter.rank:
        return 'RANK';
      case NotificationFilter.system:
        return 'SYSTEM';
    }
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final IHomeRepository _repository =
      getIt<IHomeRepository>(instanceName: 'HomeRepositoryImpl');

  NotificationFilter _selectedFilter = NotificationFilter.all;
  List<NotificationEntity> _notifications = const <NotificationEntity>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getNotifications(
      tab: _selectedFilter.backendTab,
    );

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      },
      (items) {
        setState(() {
          _isLoading = false;
          _notifications = items;
        });
      },
    );
  }

  Future<void> _markNotificationRead(NotificationEntity notification) async {
    if (notification.isRead || notification.id.isEmpty) return;

    setState(() {
      _notifications = _notifications
          .map(
            (item) =>
                item.id == notification.id ? item.copyWith(isRead: true) : item,
          )
          .toList(growable: false);
    });

    final result = await _repository.markNotificationRead(notification.id);
    if (!mounted) return;
    result.fold(
      (error) {
        setState(() {
          _notifications = _notifications
              .map(
                (item) => item.id == notification.id
                    ? item.copyWith(isRead: false)
                    : item,
              )
              .toList(growable: false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (_) {},
    );
  }

  void _selectFilter(NotificationFilter filter) {
    if (filter == _selectedFilter) return;
    setState(() {
      _selectedFilter = filter;
    });
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _NotificationsHeader(
              selectedFilter: _selectedFilter,
              onFilterChanged: _selectFilter,
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.textBrand,
                backgroundColor: const Color(0xFF242424),
                onRefresh: _loadNotifications,
                child: _NotificationsBody(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  items: _notifications,
                  onNotificationOpened: _markNotificationRead,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final NotificationFilter selectedFilter;
  final ValueChanged<NotificationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textBrand,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Notification Center',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.titleHeadline.copyWith(
                      color: AppColors.textBrand,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () =>
                      context.pushNamed(RouteNames.notificationSettings),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textBrand,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: NotificationFilter.values.length,
            separatorBuilder: (_, __) => const Gap(8),
            itemBuilder: (context, index) {
              final filter = NotificationFilter.values[index];
              final isSelected = filter == selectedFilter;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onFilterChanged(filter),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter.label,
                      style: TextStyles.bodyMain.copyWith(
                        color: isSelected
                            ? AppColors.textBrand
                            : AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
    required this.onNotificationOpened,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<NotificationEntity> items;
  final ValueChanged<NotificationEntity> onNotificationOpened;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textBrand),
      );
    }

    if (errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          Text(
            'Failed to load notifications',
            textAlign: TextAlign.center,
            style: TextStyles.titleBig.copyWith(color: AppColors.textBrand),
          ),
          const Gap(8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: TextStyles.titleBig.copyWith(color: AppColors.textBrand),
          ),
        ],
      );
    }

    final sections = _groupByDay(items);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = sections[sectionIndex];
        return Padding(
          padding: EdgeInsets.only(
            bottom: sectionIndex == sections.length - 1 ? 0 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  section.label,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              for (var index = 0; index < section.items.length; index++) ...[
                NotificationItemWidget(
                  notification: section.items[index],
                  onOpened: () => onNotificationOpened(section.items[index]),
                ),
                if (index != section.items.length - 1) const Gap(10),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_NotificationDaySection> _groupByDay(
    List<NotificationEntity> notifications,
  ) {
    final groups = <String, List<NotificationEntity>>{};

    for (final notification in notifications) {
      final label = _dayLabel(notification.createdAt);
      groups.putIfAbsent(label, () => <NotificationEntity>[]).add(notification);
    }

    return groups.entries
        .map(
          (entry) => _NotificationDaySection(
            label: entry.key,
            items: entry.value,
          ),
        )
        .toList(growable: false);
  }

  String _dayLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;

    if (difference <= 0) return 'TODAY';
    if (difference == 1) return 'YESTERDAY';

    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[local.month - 1]} ${local.day}';
  }
}

class _NotificationDaySection {
  const _NotificationDaySection({
    required this.label,
    required this.items,
  });

  final String label;
  final List<NotificationEntity> items;
}
