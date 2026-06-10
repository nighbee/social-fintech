import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/core/enums/notification_type.dart';
import 'package:app/src/features/home/domain/entities/notification_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_dto.freezed.dart';

@freezed
class NotificationDto extends BaseDto with _$NotificationDto {
  const NotificationDto._();
  const factory NotificationDto({
    required String id,
    required String kind,
    required String uiTab,
    // Action status/raw backend kind (e.g. like, follow, rejected, approved).
    required String type,
    // UI category filter type.
    required String notificationType,
    required String userId,
    required String userName,
    required String userAvatarUrl,
    required String userMeta,
    required String title,
    required String body,
    required String message,
    required String accentText,
    required String ctaLabel,
    required String ctaValue,
    required String rightImageUrl,
    required String postId,
    required DateTime createdAt,
    required bool isRead,
    required bool isImportant,
    required String badgeStatus,
    required String deepLink,
    required int groupCount,
    required List<String> actorIds,
  }) = _NotificationDto;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final normalized = json.containsKey('kind') || json.containsKey('ui_tab')
        ? _normalizeBackendNotification(json)
        : _withNotificationDefaults(json);

    return NotificationDto(
      id: _stringValue(normalized['id']),
      kind: _stringValue(normalized['kind']),
      uiTab: _stringValue(normalized['uiTab']),
      type: _stringValue(normalized['type']),
      notificationType: _stringValue(normalized['notificationType']),
      userId: _stringValue(normalized['userId']),
      userName: _stringValue(normalized['userName']),
      userAvatarUrl: _stringValue(normalized['userAvatarUrl']),
      userMeta: _stringValue(normalized['userMeta']),
      title: _stringValue(normalized['title']),
      body: _stringValue(normalized['body']),
      message: _stringValue(normalized['message']),
      accentText: _stringValue(normalized['accentText']),
      ctaLabel: _stringValue(normalized['ctaLabel']),
      ctaValue: _stringValue(normalized['ctaValue']),
      rightImageUrl: _stringValue(normalized['rightImageUrl']),
      postId: _stringValue(normalized['postId']),
      createdAt: _dateTimeValue(normalized['createdAt']),
      isRead: normalized['isRead'] == true,
      isImportant: normalized['isImportant'] == true,
      badgeStatus: _stringValue(normalized['badgeStatus']),
      deepLink: _stringValue(normalized['deepLink']),
      groupCount: _intValue(normalized['groupCount'], fallback: 1),
      actorIds: _stringList(normalized['actorIds']),
    );
  }

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        kind: kind,
        uiTab: uiTab,
        type: type,
        notificationType: NotificationType.fromString(notificationType),
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        userMeta: userMeta,
        title: title,
        body: body,
        message: message,
        accentText: accentText,
        ctaLabel: ctaLabel,
        ctaValue: ctaValue,
        rightImageUrl: rightImageUrl,
        postId: postId,
        createdAt: createdAt,
        isRead: isRead,
        isImportant: isImportant,
        badgeStatus: badgeStatus,
        deepLink: deepLink,
        groupCount: groupCount,
        actorIds: actorIds,
      );
}

Map<String, dynamic> _withNotificationDefaults(Map<String, dynamic> json) {
  final now = DateTime.now().toIso8601String();
  return <String, dynamic>{
    'id': '',
    'kind': '',
    'uiTab': '',
    'type': '',
    'notificationType': 'unknown',
    'userId': '',
    'userName': '',
    'userAvatarUrl': '',
    'userMeta': '',
    'title': '',
    'body': '',
    'message': '',
    'accentText': '',
    'ctaLabel': '',
    'ctaValue': '',
    'rightImageUrl': '',
    'postId': '',
    'createdAt': now,
    'isRead': false,
    'isImportant': false,
    'badgeStatus': '',
    'deepLink': '',
    'groupCount': 1,
    'actorIds': const <String>[],
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
    'kind': kind,
    'uiTab': uiTab,
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
    'title': title,
    'body': body,
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
    'createdAt': _stringValue(json['updated_at']).isNotEmpty
        ? _stringValue(json['updated_at'])
        : _stringValue(json['created_at']).isEmpty
            ? DateTime.now().toIso8601String()
            : _stringValue(json['created_at']),
    'isRead': json['read_at'] != null,
    'isImportant': json['is_important'] == true,
    'badgeStatus': badgeStatus,
    'deepLink': deepLink,
    'groupCount': _intValue(json['group_count'], fallback: 1),
    'actorIds': _stringList(json['actor_ids']),
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

DateTime _dateTimeValue(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(_stringValue(value)) ?? DateTime.now();
}

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

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
