import 'package:freezed_annotation/freezed_annotation.dart';

part 'status_response_entity.freezed.dart';
part 'status_response_entity.g.dart';

@freezed
class StatusResponseEntity with _$StatusResponseEntity {
  const factory StatusResponseEntity({
    required String status,
    @Default('') String error,
    @Default('') String message,
  }) = _StatusResponseEntity;

  const factory StatusResponseEntity.empty({
    @Default('') String status,
    @Default('') String error,
    @Default('') String message,
  }) = _StatusResponseEntityEmpty;

  factory StatusResponseEntity.fromJson(Map<String, dynamic> json) =>
      _$StatusResponseEntityFromJson(json);
}
