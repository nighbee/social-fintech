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
  

  const factory NotificationEntity.empty({
    @Default('') String id,
    @Default('') String type,
    @Default(NotificationType.all) NotificationType notificationType,
    @Default('') String userId,
    @Default('') String userName,
    @Default('') String userAvatarUrl,
    @Default('') String userMeta,
    @Default('') String message,
    @Default('') String accentText,
    @Default('') String ctaLabel,
    @Default('') String ctaValue,
    @Default('') String rightImageUrl,
    @Default('') String postId,
    required DateTime createdAt,
    @Default(false) bool isRead,
  }) = _NotificationEntityEmpty;

  factory NotificationEntity.fromJson(Map<String, dynamic> json) =>
      _$NotificationEntityFromJson(json);
}
