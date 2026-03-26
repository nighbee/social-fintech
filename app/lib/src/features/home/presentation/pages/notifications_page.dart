import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
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
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationFilter _selectedFilter = NotificationFilter.all;

  static final List<_NotificationItemData> _items = <_NotificationItemData>[
    _NotificationItemData(
      category: NotificationFilter.help,
      avatarUrl:
          'https://images.unsplash.com/photo-1516302752625-fcc3c50ae61f?w=240&h=240&fit=crop',
      title:
          'You earned the Founder medal for being among our first 3000 members.',
      timeAgo: '3 day ago',
    ),
    _NotificationItemData(
      category: NotificationFilter.post,
      avatarUrl:
          'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=240&h=240&fit=crop',
      title: 'Your post has been successfully published.',
      timeAgo: '3 day ago',
      trailingImage: Assets.images.image.path,
    ),
    _NotificationItemData(
      category: NotificationFilter.post,
      avatarUrl:
          'https://images.unsplash.com/photo-1545239351-1141bd82e8a6?w=240&h=240&fit=crop',
      title: 'Your post was not verified',
      highlightText: 'reason',
      timeAgo: '3 day ago',
      trailingImage: Assets.images.image.path,
    ),
    _NotificationItemData(
      category: NotificationFilter.subscriptions,
      avatarUrl:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=240&h=240&fit=crop',
      title: '@Isabbekov',
      subtitle: 'Moonstone - Intention - A',
      body: 'I sent you a honor for your post “If f...”',
      timeAgo: '3 day ago',
      trailingImage:
          'https://images.unsplash.com/photo-1472162072942-cd5147eb3902?w=220&h=220&fit=crop',
    ),
    _NotificationItemData(
      category: NotificationFilter.like,
      avatarUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=240&h=240&fit=crop',
      title: '@Ahanov',
      subtitle: 'Moonstone - Intention - A',
      body: 'I sent you a honor for your post “If f...”',
      timeAgo: '3 day ago',
      trailingImage:
          'https://images.unsplash.com/photo-1472162072942-cd5147eb3902?w=220&h=220&fit=crop',
    ),
    _NotificationItemData(
      category: NotificationFilter.help,
      avatarUrl:
          'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=240&h=240&fit=crop',
      title: '@Ahanov',
      subtitle: 'Ammolite - Intention - A',
      body: 'Request “Son\'s birthday”',
      timeAgo: '3 day ago',
      trailingCta: 'View',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visibleItems = _selectedFilter == NotificationFilter.all
        ? _items
        : _items.where((item) => item.category == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _NotificationsHeader(
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: visibleItems.length,
                separatorBuilder: (_, __) => const Gap(14),
                itemBuilder: (context, index) {
                  return _NotificationTile(item: visibleItems[index]);
                },
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _NotificationItemData item;

  @override
  Widget build(BuildContext context) {
    final hasTrailingImage = item.trailingImage != null;
    final hasTrailingCta = item.trailingCta != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.avatarUrl,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 42,
              height: 42,
              color: AppColors.surface,
              alignment: Alignment.center,
              child: Text(
                item.title.isNotEmpty ? item.title[0] : '?',
                style: TextStyles.bodyMain.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: item.title,
                      style: TextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (item.highlightText != null)
                      TextSpan(
                        text: ' ${item.highlightText!}',
                        style: TextStyles.bodyLarge.copyWith(
                          color: AppColors.blueText1,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.subtitle != null) ...[
                const Gap(2),
                Text(
                  item.subtitle!,
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFF8E95A8),
                  ),
                ),
              ],
              if (item.body != null) ...[
                const Gap(2),
                Text(
                  item.body!,
                  style: TextStyles.bodyLarge.copyWith(
                    color: Colors.white70,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Gap(2),
              Text(
                item.timeAgo,
                style: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFF8C8C8C),
                ),
              ),
            ],
          ),
        ),
        if (hasTrailingImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.trailingImage!.startsWith('http')
                ? Image.network(
                    item.trailingImage!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    item.trailingImage!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
          ),
        if (hasTrailingCta)
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF23242A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            alignment: Alignment.center,
            child: Text(
              item.trailingCta!,
              style: TextStyles.bodyLarge.copyWith(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _NotificationItemData {
  const _NotificationItemData({
    required this.category,
    required this.avatarUrl,
    required this.title,
    required this.timeAgo,
    this.highlightText,
    this.subtitle,
    this.body,
    this.trailingImage,
    this.trailingCta,
  });

  final NotificationFilter category;
  final String avatarUrl;
  final String title;
  final String timeAgo;
  final String? highlightText;
  final String? subtitle;
  final String? body;
  final String? trailingImage;
  final String? trailingCta;
}
