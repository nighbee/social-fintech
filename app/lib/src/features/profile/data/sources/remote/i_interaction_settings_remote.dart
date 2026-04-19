import 'package:fpdart/fpdart.dart';
import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';

abstract interface class IInteractionSettingsRemote {
  Future<Either<DomainException, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<DomainException, SecurityOverviewDto>> getSecurityOverview();

  Future<Either<DomainException, List<SessionItemDto>>> listSessions();

  Future<Either<DomainException, DeleteAccountReasonResponseDto>>
      deleteAccountReason({
    required String reason,
  });

  Future<Either<DomainException, DeleteAccountVerifyResponseDto>>
      deleteAccountVerify({
    String? password,
    String? otp,
  });

  Future<Either<DomainException, void>> deleteAccountFinalize({
    required String verificationToken,
  });

  Future<Either<DomainException, FeedSettingsDto>> getFeedSettings();

  Future<Either<DomainException, void>> patchFeedSettings(int newLimitMins);

  Future<Either<DomainException, InteractionsSettingsDto>> getInteractions();

  Future<Either<DomainException, MessagesSettingsDto>> getMessagesSettings();

  Future<Either<DomainException, void>> patchMessagesSettings({
    String? whoCanMessage,
    bool? readStatus,
    bool? safeMode,
  });

  Future<Either<DomainException, CommentsSettingsDto>> getCommentsSettings();

  Future<Either<DomainException, void>> patchCommentsSettings({
    String? whoCanComment,
    bool? filterUnwanted,
  });

  Future<Either<DomainException, MentionsSettingsDto>> getMentionsSettings();

  Future<Either<DomainException, void>> patchMentionsSettings({
    required String whoCanMention,
  });

  Future<Either<DomainException, BlockedUsersResponseDto>> getBlockedUsers({
    String? cursor,
    int limit,
  });

  Future<Either<DomainException, void>> unblockUser(String userId);

  Future<Either<DomainException, String>> addMessageKeyword(String keyword);

  Future<Either<DomainException, void>> deleteMessageKeyword(String id);

  Future<Either<DomainException, void>> reportBug({
    required String description,
    String? screenshotFilePath,
    required String appVersion,
    required String deviceOS,
  });
}
