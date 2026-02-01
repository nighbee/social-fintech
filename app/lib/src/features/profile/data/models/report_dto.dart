import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/profile.dart';

part 'report_dto.freezed.dart';
part 'report_dto.g.dart';

@freezed
class ReportDto with _$ReportDto {
  const factory ReportDto({
    required String id,
    @JsonKey(name: 'reporter_id') required String reporterId,
    @JsonKey(name: 'reported_user_id') required String reportedUserId,
    required String reason,
    String? description,
    required String status,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'reviewed_at') DateTime? reviewedAt,
    @JsonKey(name: 'reviewed_by') String? reviewedBy,
  }) = _ReportDto;

  const ReportDto._();

  factory ReportDto.fromJson(Map<String, dynamic> json) =>
      _$ReportDtoFromJson(json);

  UserReport toDomain() {
    return UserReport(
      id: id,
      reporterId: reporterId,
      reportedUserId: reportedUserId,
      reason: _parseReportReason(reason),
      description: description,
      status: _parseReportStatus(status),
      createdAt: createdAt,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
    );
  }

  ReportReason _parseReportReason(String reason) {
    switch (reason.toLowerCase()) {
      case 'spam':
        return ReportReason.spam;
      case 'harassment':
        return ReportReason.harassment;
      case 'inappropriate':
        return ReportReason.inappropriate;
      case 'fake_account':
        return ReportReason.fakeAccount;
      case 'other':
        return ReportReason.other;
      default:
        return ReportReason.other;
    }
  }

  ReportStatus _parseReportStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return ReportStatus.pending;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'dismissed':
        return ReportStatus.dismissed;
      case 'actioned':
        return ReportStatus.actioned;
      default:
        return ReportStatus.pending;
    }
  }
}
