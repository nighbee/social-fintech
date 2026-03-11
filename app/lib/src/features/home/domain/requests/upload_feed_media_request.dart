import 'dart:typed_data';

import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'upload_feed_media_request.freezed.dart';

@freezed
class UploadFeedMediaRequest extends BaseRequest with _$UploadFeedMediaRequest {
  const factory UploadFeedMediaRequest({
    required Uint8List bytes,
    required String fileName,
    @Default('image') String fallbackType,
  }) = _UploadFeedMediaRequest;
}
