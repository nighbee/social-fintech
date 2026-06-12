class FeedSettingsDto {
  const FeedSettingsDto({
    required this.currentMins,
    this.pendingMins,
    this.pendingApplyAt,
  });

  final int currentMins;
  final int? pendingMins;
  final DateTime? pendingApplyAt;

  factory FeedSettingsDto.fromJson(Map<String, dynamic> json) {
    DateTime? pendingAt;
    final rawAt = json['pending_apply_at'];
    if (rawAt is String && rawAt.isNotEmpty) {
      pendingAt = DateTime.tryParse(rawAt);
    }

    int? pendingMins;
    final rawPending = json['pending_mins'];
    if (rawPending is int) {
      pendingMins = rawPending;
    } else if (rawPending is num) {
      pendingMins = rawPending.toInt();
    }

    final rawCurrent = json['current_mins'];
    final currentMins = rawCurrent is int
        ? rawCurrent
        : (rawCurrent is num ? rawCurrent.toInt() : 20);

    return FeedSettingsDto(
      currentMins: currentMins,
      pendingMins: pendingMins,
      pendingApplyAt: pendingAt,
    );
  }
}

class MessagesSettingsDto {
  const MessagesSettingsDto({
    required this.whoCanMessage,
    required this.readStatus,
    required this.safeMode,
    required this.keywords,
  });

  final String whoCanMessage;
  final bool readStatus;
  final bool safeMode;
  final List<MessageKeywordItemDto> keywords;

  factory MessagesSettingsDto.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'];
    final keywords = rawKeywords is List
        ? rawKeywords
            .map(
              (e) => MessageKeywordItemDto.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList()
        : <MessageKeywordItemDto>[];

    return MessagesSettingsDto(
      whoCanMessage: json['who_can_message'] as String? ?? 'everyone',
      readStatus: json['read_status'] as bool? ?? true,
      safeMode: json['safe_mode'] as bool? ?? true,
      keywords: keywords,
    );
  }
}

class MessageKeywordItemDto {
  const MessageKeywordItemDto({
    required this.id,
    required this.keyword,
    required this.addedAt,
  });

  final String id;
  final String keyword;
  final DateTime addedAt;

  factory MessageKeywordItemDto.fromJson(Map<String, dynamic> json) {
    return MessageKeywordItemDto(
      id: json['id'] as String? ?? '',
      keyword: json['keyword'] as String? ?? '',
      addedAt: DateTime.tryParse(json['added_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class CommentsSettingsDto {
  const CommentsSettingsDto({
    required this.whoCanComment,
    required this.filterUnwanted,
  });

  final String whoCanComment;
  final bool filterUnwanted;

  factory CommentsSettingsDto.fromJson(Map<String, dynamic> json) {
    return CommentsSettingsDto(
      whoCanComment: json['who_can_comment'] as String? ?? 'everyone',
      filterUnwanted: json['filter_unwanted'] as bool? ?? false,
    );
  }
}

class MentionsSettingsDto {
  const MentionsSettingsDto({required this.whoCanMention});

  final String whoCanMention;

  factory MentionsSettingsDto.fromJson(Map<String, dynamic> json) {
    return MentionsSettingsDto(
      whoCanMention: json['who_can_mention'] as String? ?? 'everyone',
    );
  }
}

class InteractionsSettingsDto {
  const InteractionsSettingsDto({
    required this.messages,
    required this.comments,
    required this.mentions,
  });

  final MessagesSettingsDto messages;
  final CommentsSettingsDto comments;
  final MentionsSettingsDto mentions;

  factory InteractionsSettingsDto.fromJson(Map<String, dynamic> json) {
    return InteractionsSettingsDto(
      messages: MessagesSettingsDto.fromJson(
        json['messages'] as Map<String, dynamic>? ?? {},
      ),
      comments: CommentsSettingsDto.fromJson(
        json['comments'] as Map<String, dynamic>? ?? {},
      ),
      mentions: MentionsSettingsDto.fromJson(
        json['mentions'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class BlockedUserItemDto {
  const BlockedUserItemDto({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.lastActiveAt,
  });

  final String userId;
  final String username;
  final String avatarUrl;
  final DateTime lastActiveAt;

  factory BlockedUserItemDto.fromJson(Map<String, dynamic> json) {
    return BlockedUserItemDto(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      lastActiveAt:
          DateTime.tryParse(json['last_active_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class BlockedUsersResponseDto {
  const BlockedUsersResponseDto({
    required this.items,
    this.nextCursor,
  });

  final List<BlockedUserItemDto> items;
  final String? nextCursor;

  factory BlockedUsersResponseDto.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .map(
              (e) => BlockedUserItemDto.fromJson(e as Map<String, dynamic>),
            )
            .toList()
        : <BlockedUserItemDto>[];

    return BlockedUsersResponseDto(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

int effectiveFeedLimitMins(FeedSettingsDto dto) => dto.currentMins;

String feedTimeLimitLabelFromMins(int mins) {
  switch (mins) {
    case 0:
      return 'No limit';
    case 20:
      return '20 min';
    case 40:
      return '40 min';
    case 60:
      return '60 min';
    default:
      return '20 min';
  }
}

int feedTimeLimitMinsFromLabel(String label) {
  switch (label) {
    case 'No limit':
      return 0;
    case '20 min':
      return 20;
    case '40 min':
      return 40;
    case '60 min':
      return 60;
    default:
      return 20;
  }
}

class SecurityOverviewDto {
  const SecurityOverviewDto({
    required this.twoFaEnabled,
    required this.twoFaMethods,
    required this.activeSessions,
  });

  final bool twoFaEnabled;
  final List<String> twoFaMethods;
  final int activeSessions;

  factory SecurityOverviewDto.fromJson(Map<String, dynamic> json) {
    final rawMethods = json['two_fa_methods'];
    final methods = rawMethods is List
        ? rawMethods.map((e) => e.toString().toLowerCase()).toList()
        : <String>[];

    return SecurityOverviewDto(
      twoFaEnabled: json['two_fa_enabled'] as bool? ?? false,
      twoFaMethods: methods,
      activeSessions: (json['active_sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeleteAccountReasonResponseDto {
  const DeleteAccountReasonResponseDto({
    required this.verificationMethod,
  });

  final String verificationMethod;

  factory DeleteAccountReasonResponseDto.fromJson(Map<String, dynamic> json) {
    return DeleteAccountReasonResponseDto(
      verificationMethod: (json['verification_method'] as String? ?? 'password')
          .trim()
          .toLowerCase(),
    );
  }
}

class DeleteAccountVerifyResponseDto {
  const DeleteAccountVerifyResponseDto({
    required this.verificationToken,
    required this.expiresAt,
  });

  final String verificationToken;
  final DateTime? expiresAt;

  factory DeleteAccountVerifyResponseDto.fromJson(Map<String, dynamic> json) {
    final rawExpires = json['expires_at'] as String?;
    return DeleteAccountVerifyResponseDto(
      verificationToken: (json['verification_token'] as String? ?? '').trim(),
      expiresAt: (rawExpires == null || rawExpires.isEmpty)
          ? null
          : DateTime.tryParse(rawExpires),
    );
  }
}

/// Элемент GET /settings/security/sessions
class SessionItemDto {
  const SessionItemDto({
    required this.id,
    required this.deviceName,
    required this.os,
    required this.ip,
    required this.lastActiveAt,
    required this.isCurrent,
  });

  final String id;
  final String deviceName;
  final String os;
  final String ip;
  final DateTime lastActiveAt;
  final bool isCurrent;

  factory SessionItemDto.fromJson(Map<String, dynamic> json) {
    return SessionItemDto(
      id: json['id'] as String? ?? '',
      deviceName: (json['device_name'] as String?)?.trim() ?? '',
      os: (json['os'] as String?)?.trim() ?? '',
      ip: (json['ip'] as String?)?.trim() ?? '',
      lastActiveAt:
          DateTime.tryParse(json['last_active_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  /// Формат для [ActiveSessionsPage] (deviceName + details).
  Map<String, dynamic> toActiveSessionsPageMap() {
    return {
      'deviceName': _sessionTitleForUi(),
      'details': _sessionDetailsLine(),
    };
  }

  /// Если с бэка приходит UUID в [deviceName] (часто кладут `device_id`),
  /// показываем человекочитаемый тип по [os] — точная модель «iPhone 16 Pro»
  /// возможна только если клиент при логине отправит её в `device_id`/имя.
  String _sessionTitleForUi() {
    final raw = deviceName.trim();
    if (raw.isNotEmpty && !_looksLikeSessionUuid(raw)) {
      return raw;
    }
    return _friendlyOsDeviceLabelForSession(os.isNotEmpty ? os : 'unknown');
  }

  String _sessionDetailsLine() {
    final parts = <String>[];
    if (os.isNotEmpty) parts.add(os);
    if (ip.isNotEmpty) parts.add(ip);
    if (isCurrent) {
      parts.add('This device');
    } else {
      parts.add(_formatSessionLastActive(lastActiveAt));
    }
    return parts.join(' · ');
  }
}

bool _looksLikeSessionUuid(String s) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(s.trim());
}

String _friendlyOsDeviceLabelForSession(String osRaw) {
  switch (osRaw.toLowerCase()) {
    case 'ios':
    case 'ipados':
      return 'iOS device';
    case 'android':
      return 'Android device';
    case 'macos':
      return 'Mac';
    case 'windows':
      return 'Windows PC';
    case 'linux':
      return 'Linux';
    case 'web':
      return 'Web browser';
    default:
      return 'Session';
  }
}

String _formatSessionLastActive(DateTime t) {
  final now = DateTime.now();
  var diff = now.difference(t);
  if (diff.isNegative) diff = Duration.zero;
  if (diff.inMinutes < 1) return 'active now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}
