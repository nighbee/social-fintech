import 'package:app/src/core/base/base_models/base_dto.dart';
import 'package:app/src/features/home/domain/entities/media_attachment_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_attachment_dto.freezed.dart';
part 'media_attachment_dto.g.dart';

@freezed
class MediaAttachmentDto extends BaseDto with _$MediaAttachmentDto {
  const MediaAttachmentDto._();
  const factory MediaAttachmentDto({
    required String type,
    required String url,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
  }) = _MediaAttachmentDto;

  factory MediaAttachmentDto.fromJson(Map<String, dynamic> json) =>
      _$MediaAttachmentDtoFromJson(json);

  MediaAttachmentEntity toEntity() => MediaAttachmentEntity(
      type: type,
      url: url,
      thumbnailUrl: thumbnailUrl ?? '',
    );
}
