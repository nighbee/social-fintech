enum NotificationType {
  all('all'),
  like('like'),
  comment('comment'),
  help('help'),
  subscriptions('subscriptions'),
  post('post'),
  unknown('unknown');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'all':
        return NotificationType.all;
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'help':
        return NotificationType.help;
      case 'subscriptions':
      case 'subscription':
      case 'follow':
        return NotificationType.subscriptions;
      case 'post':
      case 'posts':
      case 'system':
        return NotificationType.post;
      default:
        return NotificationType.unknown;
    }
  }

  String get title {
    switch (this) {
      case NotificationType.all:
        return 'All';
      case NotificationType.like:
        return 'Like';
      case NotificationType.comment:
        return 'Comment';
      case NotificationType.help:
        return 'Help';
      case NotificationType.subscriptions:
        return 'Subscriptions';
      case NotificationType.post:
        return 'Posts';
      case NotificationType.unknown:
        return 'Unknown';
    }
  }
}
