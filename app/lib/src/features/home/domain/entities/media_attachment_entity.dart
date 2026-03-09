import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_attachment_entity.freezed.dart';
part 'media_attachment_entity.g.dart';

@freezed
class MediaAttachmentEntity with _$MediaAttachmentEntity {
  const factory MediaAttachmentEntity({
    required String type,
    required String url,
    @Default('') String thumbnailUrl,
  }) = _MediaAttachmentEntity;

  const factory MediaAttachmentEntity.empty({
    @Default('') String type,
    @Default('') String url,
    @Default('') String thumbnailUrl,
  }) = _MediaAttachmentEntityEmpty;

  factory MediaAttachmentEntity.fromJson(Map<String, dynamic> json) =>
      _$MediaAttachmentEntityFromJson(json);
}
