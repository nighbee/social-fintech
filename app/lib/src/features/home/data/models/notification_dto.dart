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

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      _$NotificationDtoFromJson(json);

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
