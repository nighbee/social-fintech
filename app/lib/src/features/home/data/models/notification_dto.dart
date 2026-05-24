import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/core/enums/notification_type.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_dto.freezed.dart';
part 'notification_dto.g.dart';

@freezed
class NotificationDto extends BaseDto with _$NotificationDto {
  const NotificationDto._();
  const factory NotificationDto({
    required String id,
    // Action status/raw backend kind (e.g. like, follow, rejected, approved).
    required String type,
    // UI category filter type.
    required String notificationType,
    required String userId,
    required String userName,
    required String userAvatarUrl,
    required String userMeta,
    required String message,
    required String accentText,
    required String ctaLabel,
    required String ctaValue,
    required String rightImageUrl,
    required String postId,
    required DateTime createdAt,
    required bool isRead,
  }) = _NotificationDto;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('kind') || json.containsKey('ui_tab')) {
      return _$NotificationDtoFromJson(_normalizeBackendNotification(json));
    }
    return _$NotificationDtoFromJson(_withNotificationDefaults(json));
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        type: type,
        notificationType: NotificationType.fromString(notificationType),
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        userMeta: userMeta,
        message: message,
        accentText: accentText,
        ctaLabel: ctaLabel,
        ctaValue: ctaValue,
        rightImageUrl: rightImageUrl,
        postId: postId,
        createdAt: createdAt,
        isRead: isRead,
      );
}

Map<String, dynamic> _withNotificationDefaults(Map<String, dynamic> json) {
  final now = DateTime.now().toIso8601String();
  return <String, dynamic>{
    'id': '',
    'type': '',
    'notificationType': 'unknown',
    'userId': '',
    'userName': '',
    'userAvatarUrl': '',
    'userMeta': '',
    'message': '',
    'accentText': '',
    'ctaLabel': '',
    'ctaValue': '',
    'rightImageUrl': '',
    'postId': '',
    'createdAt': now,
    'isRead': false,
    ...json,
  };
}

Map<String, dynamic> _normalizeBackendNotification(Map<String, dynamic> json) {
  final payload = _mapValue(json['payload']);
  final kind = _stringValue(json['kind']);
  final uiTab = _stringValue(json['ui_tab']);
  final badgeStatus = _stringValue(json['badge_status']);
  final title = _stringValue(json['title']);
  final body = _stringValue(json['body']);
  final deepLink = _stringValue(json['deep_link']);
  final reason = _firstString(payload, const <String>[
    'reason',
    'moderation_reason',
    'rejection_reason',
  ]);

  return <String, dynamic>{
    'id': _stringValue(json['id']),
    'type': badgeStatus.isNotEmpty ? badgeStatus.toLowerCase() : kind,
    'notificationType': _notificationTypeFor(kind, uiTab, badgeStatus),
    'userId': _firstString(payload, const <String>[
      'actor_id',
      'creator_id',
      'helper_id',
      'sender_id',
    ]),
    'userName': _firstString(payload, const <String>[
      'actor_username',
      'actor_name',
      'username',
      'sender_username',
    ]),
    'userAvatarUrl': _firstString(payload, const <String>[
      'actor_avatar_url',
      'avatar_url',
      'sender_avatar_url',
    ]),
    'userMeta': _firstString(payload, const <String>[
      'actor_meta',
      'user_meta',
      'rank_label',
    ]),
    'message': body.isEmpty ? title : '$title $body',
    'accentText': reason.isNotEmpty ? 'reason' : '',
    'ctaLabel': _ctaLabelFor(kind, uiTab, deepLink),
    'ctaValue': reason.isNotEmpty ? reason : deepLink,
    'rightImageUrl': _firstString(payload, const <String>[
      'post_image_url',
      'image_url',
      'thumbnail_url',
      'media_url',
    ]),
    'postId': _firstString(payload, const <String>[
      'post_id',
      'task_id',
      'conversation_id',
    ]),
    'createdAt': _stringValue(json['created_at']).isEmpty
        ? DateTime.now().toIso8601String()
        : _stringValue(json['created_at']),
    'isRead': json['read_at'] != null,
  };
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

String _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _stringValue(dynamic value) => value?.toString() ?? '';

String _notificationTypeFor(String kind, String uiTab, String badgeStatus) {
  switch (kind) {
    case 'post_liked':
      return 'like';
    case 'post_commented':
    case 'message_received':
      return 'comment';
    case 'seal_received':
      return 'subscriptions';
    case 'task_applied':
    case 'task_accepted':
    case 'task_completed':
      return 'help';
  }

  switch (uiTab.toUpperCase()) {
    case 'TASKS':
      return 'help';
    case 'RECOGNITION':
      return 'subscriptions';
    case 'SYSTEM':
      return 'post';
    case 'ACTIVITY':
      return 'comment';
  }

  if (badgeStatus.toUpperCase() == 'REJECTED') return 'post';
  return 'unknown';
}

String _ctaLabelFor(String kind, String uiTab, String deepLink) {
  if (deepLink.isEmpty) return '';
  if (uiTab.toUpperCase() == 'TASKS' || kind.startsWith('task_')) {
    return 'View';
  }
  return '';
}
