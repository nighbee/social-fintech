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

  String get title {
    switch (this) {
      case NotificationFilter.post:
        return 'Posts';
      case NotificationFilter.all:
      case NotificationFilter.like:
      case NotificationFilter.comment:
      case NotificationFilter.help:
      case NotificationFilter.subscriptions:
        return label;
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
  bool _isFilterMenuOpen = false;
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
        child: Stack(
          children: [
            Column(
              children: [
                _NotificationsHeader(
                  selectedFilter: _selectedFilter,
                  isFilterMenuOpen: _isFilterMenuOpen,
                  onMenuTap: () {
                    setState(() {
                      _isFilterMenuOpen = !_isFilterMenuOpen;
                    });
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
            if (_isFilterMenuOpen) ...[
              Positioned.fill(
                top: 56,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    setState(() {
                      _isFilterMenuOpen = false;
                    });
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                top: 52,
                right: 24,
                child: _NotificationFilterMenu(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (filter) {
                    if (filter == _selectedFilter) {
                      setState(() {
                        _isFilterMenuOpen = false;
                      });
                      return;
                    }
                    setState(() {
                      _selectedFilter = filter;
                      _isFilterMenuOpen = false;
                    });
                    _loadNotifications();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.selectedFilter,
    required this.isFilterMenuOpen,
    required this.onMenuTap,
  });

  final NotificationFilter selectedFilter;
  final bool isFilterMenuOpen;
  final VoidCallback onMenuTap;

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
              IconButton(
                onPressed: onMenuTap,
                icon: Icon(
                  Icons.more_vert,
                  color: isFilterMenuOpen
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const Gap(8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selectedFilter.title,
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

class _NotificationFilterMenu extends StatelessWidget {
  const _NotificationFilterMenu({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final NotificationFilter selectedFilter;
  final ValueChanged<NotificationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 118,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF17191F).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final filter in NotificationFilter.values)
              _NotificationFilterMenuItem(
                filter: filter,
                isSelected: filter == selectedFilter,
                onTap: () => onFilterChanged(filter),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationFilterMenuItem extends StatelessWidget {
  const _NotificationFilterMenuItem({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final NotificationFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              filter.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.bodyMain.copyWith(
                fontSize: 14,
                height: 1.2,
                color: isSelected
                    ? AppColors.colorffffffff
                    : AppColors.colorffcacaca,
              ),
            ),
          ),
        ),
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
