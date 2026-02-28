import 'package:app/src/core/base/base_models/base_request.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_champions_request_dto.freezed.dart';
part 'map_champions_request_dto.g.dart';

@freezed
class MapChampionsRequestDto extends BaseRequest with _$MapChampionsRequestDto {
  const factory MapChampionsRequestDto({
    required List<String> h3Indices,
    @Default(5) int resolution,
    int? year,
    int? week,
  }) = _MapChampionsRequestDto;

  factory MapChampionsRequestDto.fromJson(Map<String, dynamic> json) =>
      _$MapChampionsRequestDtoFromJson(json);
}
