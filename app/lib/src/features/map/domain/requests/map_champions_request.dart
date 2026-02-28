import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_champions_request.freezed.dart';
part 'map_champions_request.g.dart';

@freezed
class MapChampionsRequest extends BaseRequest with _$MapChampionsRequest {
  const factory MapChampionsRequest({
    required List<String> h3Indices,
    @Default(5) int resolution,
    int? year,
    int? week,
  }) = _MapChampionsRequest;

  factory MapChampionsRequest.fromJson(Map<String, dynamic> json) =>
      _$MapChampionsRequestFromJson(json);
}
