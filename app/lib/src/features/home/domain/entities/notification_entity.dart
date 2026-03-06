import 'package:app/src/core/enums/notification_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_entity.freezed.dart';
part 'notification_entity.g.dart';

@freezed
class NotificationEntity with _$NotificationEntity {
  const factory NotificationEntity({
    required String id,
    // Action status/raw backend kind (e.g. like, follow, rejected, approved).
    required String type,
    // UI category filter type.
    required NotificationType notificationType,
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
  }) = _NotificationEntity;

  factory NotificationEntity.fromJson(Map<String, dynamic> json) =>
      _$NotificationEntityFromJson(json);
}
