import 'package:app/src/core/enums/notification_type.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:app/src/features/home/domain/repositories/i_home_repository.dart';
import 'package:app/src/features/home/presentation/widgets/notification_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum NotificationFilter { all, like, comment, help, subscriptions, post }

extension _NotificationFilterLabel on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.like:
        return 'Like';
      case NotificationFilter.comment:
        return 'Comment';
      case NotificationFilter.help:
        return 'Help';
      case NotificationFilter.subscriptions:
        return 'Subscriptions';
      case NotificationFilter.post:
        return 'Post';
    }
  }

  String? get backendTab {
    switch (this) {
      case NotificationFilter.all:
        return null;
      case NotificationFilter.like:
      case NotificationFilter.comment:
        return 'ACTIVITY';
      case NotificationFilter.help:
        return 'TASKS';
      case NotificationFilter.subscriptions:
        return 'RECOGNITION';
      case NotificationFilter.post:
        return 'SYSTEM';
    }
  }

  NotificationType? get localType {
    switch (this) {
      case NotificationFilter.all:
        return null;
      case NotificationFilter.like:
        return NotificationType.like;
      case NotificationFilter.comment:
        return NotificationType.comment;
      case NotificationFilter.help:
        return NotificationType.help;
      case NotificationFilter.subscriptions:
        return NotificationType.subscriptions;
      case NotificationFilter.post:
        return NotificationType.post;
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

  List<NotificationEntity> get _visibleNotifications {
    final localType = _selectedFilter.localType;
    if (localType == null) return _notifications;
    return _notifications
        .where((item) => item.notificationType == localType)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleNotifications;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _NotificationsHeader(
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                if (filter == _selectedFilter) return;
                setState(() {
                  _selectedFilter = filter;
                });
                _loadNotifications();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: Colors.white,
                backgroundColor: const Color(0xFF17191F),
                onRefresh: _loadNotifications,
                child: _NotificationsBody(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  items: visibleItems,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'Notification',
                  textAlign: TextAlign.center,
                  style: TextStyles.titleHeadline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 34 / 1.9,
                  ),
                ),
              ),
              PopupMenuButton<NotificationFilter>(
                color: const Color(0xFF17191F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x28FFFFFF)),
                ),
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: onFilterChanged,
                itemBuilder: (context) => NotificationFilter.values
                    .map(
                      (filter) => PopupMenuItem<NotificationFilter>(
                        value: filter,
                        child: Text(
                          filter.label,
                          style: TextStyles.bodyLarge.copyWith(
                            color: filter == selectedFilter
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selectedFilter.label,
              style: TextStyles.titleBig.copyWith(
                color: Colors.white,
                fontSize: 40 / 1.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.isLoading,
    required this.errorMessage,
    required this.items,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<NotificationEntity> items;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        children: [
          Text(
            'Failed to load notifications',
            textAlign: TextAlign.center,
            style: TextStyles.titleBig.copyWith(color: Colors.white),
          ),
          const Gap(8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyles.bodyLarge.copyWith(color: Colors.white60),
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
            style: TextStyles.titleBig.copyWith(color: Colors.white),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Gap(14),
      itemBuilder: (context, index) {
        return NotificationItemWidget(notification: items[index]);
      },
    );
  }
}
