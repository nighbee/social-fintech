import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/data/services/chat_realtime_service.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_message_api_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    required this.chatId,
    super.key,
    this.threadPreview,
  });

  final String chatId;

  /// Передаётся с [ChatsPage] при открытии из списка API; иначе — заглушка для старых маршрутов.
  final ChatThreadPreview? threadPreview;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  late ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  late List<ChatMessageUiModel> _messages;
  bool _loadingRemote = false;
  String? _remoteError;
  bool _sending = false;
  _PendingMedia? _pendingMedia;
  _ChatReplyDraft? _replyDraft;
  List<MessageDto> _remoteMessageDtos = <MessageDto>[];
  final Set<String> _locallySentMessageIds = <String>{};
  String? _actionOverlayMessageId;
  String? _resolvedCurrentUserId;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  IProfileRemote get _profileRemote =>
      getIt<IProfileRemote>(instanceName: 'ProfileRemoteImpl');

  bool get _isRealConversation =>
      chatConversationIdLooksLikeUuid(widget.chatId.trim());

  String? _currentUserId() {
    final resolved = _resolvedCurrentUserId?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final authId = getIt<AuthBloc>().state.maybeWhen(
          authenticated: (loginEntity) => loginEntity.user.id,
          orElse: () => null,
        );
    final fromAuth = authId?.trim();
    if (fromAuth != null && fromAuth.isNotEmpty) {
      return fromAuth;
    }
    final profileId = getIt<ProfileBloc>().state.maybeWhen(
          loaded: (ProfileViewModel vm) => vm.profile.userId,
          loading: (ProfileViewModel vm) => vm.profile.userId,
          orElse: () => null,
        );
    final fromProfile = profileId?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    return null;
  }

  Future<String?> _ensureCurrentUserId() async {
    final existing = _currentUserId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final result = await _profileRemote.getCurrentUser();
    if (!mounted) {
      return null;
    }
    final fetched = result.fold(
      (_) => null,
      (profile) => profile.userId.trim(),
    );
    if (fetched != null && fetched.isNotEmpty) {
      setState(() {
        _resolvedCurrentUserId = fetched;
      });
      return fetched;
    }
    return null;
  }

  String _profileUserId(ProfileState s) => s.maybeWhen(
        loaded: (ProfileViewModel vm) => vm.profile.userId.trim(),
        loading: (ProfileViewModel vm) => vm.profile.userId.trim(),
        orElse: () => '',
      );

  String _authUserId(AuthState s) => s.maybeWhen(
        authenticated: (loginEntity) => loginEntity.user.id.trim(),
        orElse: () => '',
      );

  Future<void> _remapMessagesFromRemoteDtos() async {
    if (!_isRealConversation || _remoteMessageDtos.isEmpty) {
      return;
    }
    final uid = await _ensureCurrentUserId();
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _messages = ChatMessageApiMapper.toUiModels(
        _remoteMessageDtos,
        currentUserId: uid,
        forceOutgoingMessageIds: _locallySentMessageIds,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _thread = widget.threadPreview ??
        ChatThreadPreview(
          id: widget.chatId.trim(),
          displayName: 'Чат',
          rankLine: '',
          lastSeenLabel: '',
          timeLabel: '',
          avatarUrl: '',
        );
    _messageController = TextEditingController();
    _messages = <ChatMessageUiModel>[];
    if (_isRealConversation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadRemoteMessages());
        unawaited(_enrichHeaderFromProfile());
      });
      _realtimeSubscription = ChatRealtimeService.instance.events.listen(
        _handleRealtimeEvent,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _remoteError = 'Некорректный идентификатор чата';
          });
        }
      });
    }
  }

  Future<void> _enrichHeaderFromProfile() async {
    final otherId = _thread.otherUserId?.trim();
    if (otherId == null || otherId.isEmpty) {
      return;
    }
    final result = await _profileRemote.getPublicProfile(
      UserIdRequest(userId: otherId),
    );
    if (!mounted) {
      return;
    }
    result.fold((_) {}, (dto) {
      final entity = dto.toEntity();
      final dn = entity.displayName.trim();
      final av = entity.avatarUrl.trim();
      setState(() {
        _thread = _thread.copyWith(
          displayName: dn.isNotEmpty ? dn : _thread.displayName,
          avatarUrl: av.isNotEmpty ? av : _thread.avatarUrl,
        );
      });
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted || !_isRealConversation) {
      return;
    }
    final eventConversationId = event.conversationId?.trim();
    if (eventConversationId == null ||
        eventConversationId != widget.chatId.trim()) {
      return;
    }

    switch (event.type) {
      case 'message.new':
        final dto = event.message;
        if (dto == null) {
          return;
        }
        _upsertRemoteMessage(dto);
        final messageId = dto.id.trim();
        ChatRealtimeService.instance.markRead(
          conversationId: widget.chatId.trim(),
          lastReadMessageId: messageId.isEmpty ? null : messageId,
        );
        return;
      case 'conversation.request_accepted':
        setState(() {
          _thread = _thread.copyWith(
            isRequest: false,
            requestStatus: event.requestStatus ?? 'accepted',
          );
        });
        return;
      case 'conversation.request_declined':
        setState(() {
          _thread = _thread.copyWith(
            requestStatus: event.requestStatus ?? 'declined',
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat request declined')),
        );
        return;
      case 'message.deleted':
        final messageId = event.messageId?.trim();
        if (messageId == null || messageId.isEmpty) {
          return;
        }
        setState(() {
          _remoteMessageDtos = _remoteMessageDtos
              .where((message) => message.id.trim() != messageId)
              .toList(growable: false);
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: _currentUserId(),
            forceOutgoingMessageIds: _locallySentMessageIds,
          );
        });
        unawaited(_loadPinnedMessages());
        return;
      case 'message.pinned':
      case 'message.unpinned':
        unawaited(_loadPinnedMessages());
        return;
      case 'conversation.deleted':
      case 'conversation.cleared':
        setState(() {
          _remoteMessageDtos = <MessageDto>[];
          _messages = <ChatMessageUiModel>[];
        });
        return;
    }
  }

  void _upsertRemoteMessage(MessageDto dto) {
    final dtoId = dto.id.trim();
    setState(() {
      if (dto.senderId?.trim() == _currentUserId()) {
        _locallySentMessageIds.add(dto.id.trim());
      }
      final index = dtoId.isEmpty
          ? -1
          : _remoteMessageDtos.indexWhere((m) => m.id.trim() == dtoId);
      if (index == -1) {
        _remoteMessageDtos = [..._remoteMessageDtos, dto];
      } else {
        final next = List<MessageDto>.from(_remoteMessageDtos);
        next[index] = dto;
        _remoteMessageDtos = next;
      }
      _messages = ChatMessageApiMapper.toUiModels(
        _remoteMessageDtos,
        currentUserId: _currentUserId(),
        forceOutgoingMessageIds: _locallySentMessageIds,
      );
    });
  }

  String _replyLabelForMessage(ChatMessageUiModel m) {
    if (m.direction == ChatMessageDirection.outgoing) {
      return 'You';
    }
    final name = _thread.displayName.trim();
    return name.isNotEmpty ? name : 'Original message';
  }

  String _messageExcerpt(ChatMessageUiModel m) {
    final t = m.text.trim();
    if (t.isNotEmpty) {
      if (t.length > 120) {
        return '${t.substring(0, 117)}…';
      }
      return t;
    }
    if (m.media.isNotEmpty) {
      final first = m.media.first;
      if (first.isImage) {
        return 'Фото';
      }
      if (first.isVideo) {
        return 'Видео';
      }
      if (first.isAudio) {
        return 'Голосовое сообщение';
      }
      return 'Вложение';
    }
    if (m.forwardedSnippet != null) {
      return 'Пересланное сообщение';
    }
    return 'Сообщение';
  }

  /// Текст тела для API: без префикса в теле — ответ задаётся `reply_to_message_id`.
  String _outgoingBodyForBackend(String userText) {
    return userText.trim();
  }

  void _onMessageLongPressAt(ChatMessageUiModel m, Offset globalPosition) {
    _openMessageActionsForModelAt(m, globalPosition);
  }

  Future<void> _openMessageActionsForModelAt(
    ChatMessageUiModel m,
    Offset globalPosition,
  ) async {
    final isSystem = m.messageType == 'system';
    final canCopy = _messageExcerpt(m).trim().isNotEmpty;

    setState(() => _actionOverlayMessageId = m.id);
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Message actions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) {
        return _ChatMessageActionsOverlay(
          message: m,
          anchor: globalPosition,
          showReply: !isSystem,
          showCopy: canCopy,
          showDelete: !isSystem,
          onSelected: (value) => Navigator.of(dialogContext).pop(value),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
    if (mounted && _actionOverlayMessageId == m.id) {
      setState(() => _actionOverlayMessageId = null);
    }

    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case 'reply':
        setState(() {
          _replyDraft = _ChatReplyDraft(
            authorLabel: _replyLabelForMessage(m),
            excerpt: _messageExcerpt(m),
            replyToMessageId: m.id.trim().isEmpty ? null : m.id.trim(),
          );
        });
        return;
      case 'forward':
        context.pushNamed(
          RouteNames.chatConversationForward,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'copy':
        final clip = m.text.trim().isNotEmpty ? m.text : _messageExcerpt(m);
        Clipboard.setData(ClipboardData(text: clip));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied')),
        );
        return;
      case 'delete':
        unawaited(_deleteMessageApi(m.id, forBoth: false));
        return;
      case 'select':
        context.pushNamed(
          RouteNames.chatConversationSelect,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'report':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report is not available yet')),
        );
        return;
    }
  }

  Future<void> _deleteMessageApi(String messageId,
      {required bool forBoth}) async {
    if (!mounted || !_isRealConversation) {
      return;
    }
    final res = await _remote.deleteMessage(
      conversationId: widget.chatId.trim(),
      messageId: messageId,
      forBoth: forBoth,
    );
    if (!mounted) {
      return;
    }
    res.fold(
      (DomainException e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message))),
      (_) async {
        await _loadRemoteMessages();
        await _loadPinnedMessages();
      },
    );
  }

  Future<void> _loadPinnedMessages() async {
    if (!_isRealConversation) {
      return;
    }
    final r = await _remote.listPinnedMessages(
      conversationId: widget.chatId.trim(),
    );
    if (!mounted) {
      return;
    }
    r.fold((_) {}, (dto) {
      if (dto.items.isEmpty) {
        setState(() {
          _thread = _thread.copyWith(
            pinnedMessagePreview: null,
            pinnedMessageId: null,
          );
        });
        return;
      }
      final p = dto.items.first;
      final text = p.messageBody.trim();
      if (text.isEmpty) {
        return;
      }
      setState(() {
        _thread = _thread.copyWith(
          pinnedMessagePreview:
              text.length > 160 ? '${text.substring(0, 157)}…' : text,
          pinnedMessageId:
              p.messageId.trim().isEmpty ? null : p.messageId.trim(),
        );
      });
    });
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'mute':
        unawaited(_setConversationMuted(!_thread.isMuted));
        return;
      case 'pin':
        unawaited(_setConversationPinned(!_thread.isPinned));
        return;
      case 'forward':
        context.pushNamed(
          RouteNames.chatConversationForward,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'select':
        context.pushNamed(
          RouteNames.chatConversationSelect,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'block':
        context.pushNamed(
          RouteNames.chatConversationBlocked,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'delete':
        context.pushNamed(
          RouteNames.chatConversationDeleted,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
    }
  }

  Future<void> _setConversationMuted(bool muted) async {
    if (!_isRealConversation) {
      return;
    }
    final result = await _remote.setConversationMuted(
      conversationId: widget.chatId.trim(),
      muted: muted,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (DomainException error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (_) {
        setState(() => _thread = _thread.copyWith(isMuted: muted));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(muted ? 'Muted' : 'Unmuted')),
        );
      },
    );
  }

  Future<void> _setConversationPinned(bool pinned) async {
    if (!_isRealConversation) {
      return;
    }
    final result = await _remote.setConversationPinned(
      conversationId: widget.chatId.trim(),
      pinned: pinned,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (DomainException error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (_) {
        setState(() => _thread = _thread.copyWith(isPinned: pinned));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pinned ? 'Chat pinned' : 'Chat unpinned')),
        );
      },
    );
  }

  Future<void> _loadRemoteMessages() async {
    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });
    final currentUserId = await _ensureCurrentUserId();
    if (!mounted) {
      return;
    }
    final result = await _remote.listMessages(
      conversationId: widget.chatId.trim(),
      limit: 50,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (DomainException error) {
        setState(() {
          _loadingRemote = false;
          _remoteError = error.message;
          _messages = <ChatMessageUiModel>[];
          _remoteMessageDtos = <MessageDto>[];
        });
      },
      (data) {
        setState(() {
          _loadingRemote = false;
          _remoteError = null;
          _remoteMessageDtos = List<MessageDto>.from(data.items);
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: currentUserId ?? _currentUserId(),
            forceOutgoingMessageIds: _locallySentMessageIds,
          );
        });
        final items = data.items;
        if (items.isNotEmpty) {
          unawaited(
            _remote.markConversationRead(
              conversationId: widget.chatId.trim(),
              lastReadMessageId: items.last.id,
            ),
          );
        } else {
          unawaited(
            _remote.markConversationRead(
              conversationId: widget.chatId.trim(),
            ),
          );
        }
        unawaited(_loadPinnedMessages());
      },
    );
  }

  List<Map<String, dynamic>> _chatMediaPayload(
    List<({String type, String url, String? thumbnailUrl})> items,
  ) {
    return items
        .map(
          (e) => <String, dynamic>{
            'type': e.type,
            'url': e.url,
            if ((e.thumbnailUrl ?? '').trim().isNotEmpty)
              'thumbnail_url': e.thumbnailUrl!.trim(),
          },
        )
        .toList(growable: false);
  }

  Future<void> _onPickAttachment() async {
    if (!_isRealConversation || _sending) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Attachment picker',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (dialogContext, _, __) {
        return _ChatAttachmentPickerOverlay(
          left: 40,
          bottom: MediaQuery.paddingOf(context).bottom + 52,
          onSelected: (value) => Navigator.of(dialogContext).pop(value),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
    if (size == Size.zero) {
      return;
    }
    if (!mounted || selected == null) {
      return;
    }

    void onMediaSelected(Uint8List bytes, String fileName) {
      if (!mounted) {
        return;
      }
      setState(() =>
          _pendingMedia = _PendingMedia(bytes: bytes, fileName: fileName));
    }

    void onError(String message) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (selected == 'camera') {
      await ImagePickerHelper.pickCameraMedia(
        onMediaSelected: onMediaSelected,
        onError: onError,
      );
    } else {
      await ImagePickerHelper.pickGalleryMedia(
        onMediaSelected: onMediaSelected,
        onError: onError,
      );
    }
  }

  Future<void> _uploadAndSend(
    Uint8List bytes,
    String fileName, {
    String caption = '',
  }) async {
    if (!mounted || _sending) {
      return;
    }
    setState(() => _sending = true);
    final upload = await _remote.uploadChatMedia(
      bytes: bytes,
      fileName: fileName,
    );
    if (!mounted) {
      return;
    }
    final uploaded = upload.fold((e) => null, (a) => a);
    if (uploaded == null) {
      setState(() => _sending = false);
      upload.fold(
        (e) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        ),
        (_) {},
      );
      return;
    }
    final trimmedCaption = caption.trim();
    final bodyForApi = _outgoingBodyForBackend(trimmedCaption);
    final idempotencyKey = const Uuid().v4();
    final result = await _remote.sendMessage(
      conversationId: widget.chatId.trim(),
      body: bodyForApi,
      idempotencyKey: idempotencyKey,
      media: _chatMediaPayload([
        (
          type: uploaded.type,
          url: uploaded.url,
          thumbnailUrl: uploaded.thumbnailUrl,
        ),
      ]),
      replyToMessageId: _replyDraft?.replyToMessageId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    result.fold(
      (DomainException error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (dto) {
        _messageController.clear();
        setState(() {
          final sentId = dto.id.trim();
          if (sentId.isNotEmpty) {
            _locallySentMessageIds.add(sentId);
          }
          _pendingMedia = null;
          _replyDraft = null;
          _remoteMessageDtos = [..._remoteMessageDtos, dto];
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: _currentUserId(),
            forceOutgoingMessageIds: _locallySentMessageIds,
          );
        });
      },
    );
  }

  void _onMicrophoneTap() {
    if (!_isRealConversation) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Voice messages: the server only accepts image/video on '
          '/feed/media/upload — audio upload is not available yet.',
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (_sending) {
      return;
    }

    if (_isRealConversation && _pendingMedia != null) {
      await _uploadAndSend(
        _pendingMedia!.bytes,
        _pendingMedia!.fileName,
        caption: text,
      );
      return;
    }

    if (text.isEmpty) {
      return;
    }

    if (!_isRealConversation) {
      return;
    }

    setState(() => _sending = true);
    final idempotencyKey = const Uuid().v4();
    final result = await _remote.sendMessage(
      conversationId: widget.chatId.trim(),
      body: _outgoingBodyForBackend(text),
      idempotencyKey: idempotencyKey,
      replyToMessageId: _replyDraft?.replyToMessageId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);

    result.fold(
      (DomainException error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (dto) {
        _messageController.clear();
        setState(() {
          final sentId = dto.id.trim();
          if (sentId.isNotEmpty) {
            _locallySentMessageIds.add(sentId);
          }
          _replyDraft = null;
          _remoteMessageDtos = [..._remoteMessageDtos, dto];
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: _currentUserId(),
            forceOutgoingMessageIds: _locallySentMessageIds,
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget scaffold = ChatScaffold(
      backgroundVariant: ChatBackgroundVariant.thread,
      overlayBottomNavigationBar: true,
      appBar: ChatDetailAppBar(
        thread: _thread,
        actions: [
          ChatConversationOverflowButton(
            isMuted: _thread.isMuted,
            isPinned: _thread.isPinned,
            onSelected: _handleMenuSelection,
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.02),
            ),
            child: Material(
              type: MaterialType.transparency,
              color: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyDraft != null)
                    _ChatReplyComposerPanel(
                      draft: _replyDraft!,
                      onClose: () {
                        if (_sending) {
                          return;
                        }
                        setState(() => _replyDraft = null);
                      },
                      composer: ChatComposerBar(
                        controller: _messageController,
                        onSend: _sendMessage,
                        sendEnabled: !_sending,
                        hasPendingAttachment:
                            _isRealConversation && _pendingMedia != null,
                        onAttachmentTap:
                            _isRealConversation ? _onPickAttachment : null,
                        onMicrophoneTap:
                            _isRealConversation ? _onMicrophoneTap : null,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        useSafeArea: false,
                      ),
                    ),
                  if (_isRealConversation && _pendingMedia != null)
                    _ChatPendingMediaStrip(
                      data: _pendingMedia!,
                      onRemove: () {
                        if (_sending) {
                          return;
                        }
                        setState(() => _pendingMedia = null);
                      },
                    ),
                  if (_replyDraft == null)
                    ChatComposerBar(
                      controller: _messageController,
                      onSend: _sendMessage,
                      sendEnabled: !_sending,
                      hasPendingAttachment:
                          _isRealConversation && _pendingMedia != null,
                      onAttachmentTap:
                          _isRealConversation ? _onPickAttachment : null,
                      onMicrophoneTap:
                          _isRealConversation ? _onMicrophoneTap : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _isRealConversation && _loadingRemote
            ? const Center(child: CircularProgressIndicator())
            : _isRealConversation && _remoteError != null && _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _remoteError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadRemoteMessages,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ChatConversationMessageList(
                    messages: _messages,
                    hiddenMessageIds: _actionOverlayMessageId == null
                        ? const <String>{}
                        : <String>{_actionOverlayMessageId!},
                    onMessageLongPressAt: _onMessageLongPressAt,
                    emptyState: _isRealConversation &&
                            !_loadingRemote &&
                            _remoteError == null &&
                            _messages.isEmpty
                        ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              chatThreadComposerStackBottomPadding(
                                context,
                                hasPendingAttachment: _isRealConversation &&
                                    _pendingMedia != null,
                                hasReplyDraft: _replyDraft != null,
                              ),
                            ),
                            child: const _NoMessagesEmptyState(),
                          )
                        : null,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      chatThreadComposerStackBottomPadding(
                        context,
                        hasPendingAttachment:
                            _isRealConversation && _pendingMedia != null,
                        hasReplyDraft: _replyDraft != null,
                      ),
                    ),
                  ),
      ),
    );

    if (!_isRealConversation) {
      return scaffold;
    }

    return BlocListener<ProfileBloc, ProfileState>(
      listenWhen: (ProfileState previous, ProfileState current) =>
          _remoteMessageDtos.isNotEmpty &&
          _profileUserId(previous) != _profileUserId(current),
      listener: (BuildContext context, ProfileState state) {
        unawaited(_remapMessagesFromRemoteDtos());
      },
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (AuthState previous, AuthState current) =>
            _remoteMessageDtos.isNotEmpty &&
            _authUserId(previous) != _authUserId(current),
        listener: (BuildContext context, AuthState state) {
          unawaited(_remapMessagesFromRemoteDtos());
        },
        child: scaffold,
      ),
    );
  }
}

class _PendingMedia {
  _PendingMedia({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;

  bool get isVideo {
    final n = fileName.toLowerCase();
    return n.endsWith('.mp4') ||
        n.endsWith('.mov') ||
        n.endsWith('.m4v') ||
        n.endsWith('.webm');
  }
}

class _ChatAttachmentPickerOverlay extends StatelessWidget {
  const _ChatAttachmentPickerOverlay({
    required this.left,
    required this.bottom,
    required this.onSelected,
  });

  final double left;
  final double bottom;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            bottom: bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF18191C),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 116,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChatAttachmentMenuRow(
                      label: 'Media',
                      icon: Icons.insert_drive_file_outlined,
                      onTap: () => onSelected('media'),
                    ),
                    _ChatAttachmentMenuRow(
                      label: 'Camera',
                      icon: Icons.camera_alt_outlined,
                      onTap: () => onSelected('camera'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatAttachmentMenuRow extends StatelessWidget {
  const _ChatAttachmentMenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textBrand,
                    fontSize: 11,
                    height: 1,
                  ),
                ),
              ),
              Icon(
                icon,
                color: AppColors.textBrand.withValues(alpha: 0.88),
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMessagesEmptyState extends StatelessWidget {
  const _NoMessagesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/message.png',
              width: 74,
              height: 74,
              fit: BoxFit.contain,
            ),
            const Gap(16),
            Text(
              'No messages yet',
              style: TextStyles.titleMain.copyWith(
                color: AppColors.textBrand,
                fontSize: 20,
                height: 1.15,
              ),
            ),
            const Gap(10),
            Text(
              'Start the conversation!',
              style: TextStyles.bodyMain.copyWith(
                color: AppColors.textBrand.withValues(alpha: 0.68),
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageActionsOverlay extends StatelessWidget {
  const _ChatMessageActionsOverlay({
    required this.message,
    required this.anchor,
    required this.showReply,
    required this.showCopy,
    required this.showDelete,
    required this.onSelected,
  });

  final ChatMessageUiModel message;
  final Offset anchor;
  final bool showReply;
  final bool showCopy;
  final bool showDelete;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const menuWidth = 146.0;
    final outgoing = message.direction == ChatMessageDirection.outgoing;
    final left = (outgoing ? anchor.dx - menuWidth + 28 : anchor.dx - 58)
        .clamp(36.0, size.width - menuWidth - 20)
        .toDouble();
    final top =
        (anchor.dy - 38).clamp(padding.top + 116, size.height - 286).toDouble();
    final bubbleWidth = outgoing ? 220.0 : 146.0;
    final bubbleLeft = (outgoing ? left + menuWidth - bubbleWidth : left)
        .clamp(20.0, size.width - bubbleWidth - 20)
        .toDouble();
    final textLines = (message.text.length / 18).ceil().clamp(1, 3);
    final bubbleHeight = message.replyPreview == null
        ? 28.0 + textLines * 22.0
        : 76.0 + textLines * 22.0;

    final actions = <_ChatActionMenuEntry>[
      if (showReply)
        const _ChatActionMenuEntry(
          value: 'reply',
          label: 'Reply',
          icon: Icons.reply_rounded,
        ),
      if (showCopy)
        const _ChatActionMenuEntry(
          value: 'copy',
          label: 'Copy',
          icon: Icons.copy_rounded,
        ),
      const _ChatActionMenuEntry(
        value: 'forward',
        label: 'Forward',
        icon: Icons.subdirectory_arrow_right_rounded,
      ),
      const _ChatActionMenuEntry(
        value: 'select',
        label: 'Select',
        icon: Icons.check_circle_outline_rounded,
      ),
      const _ChatActionMenuEntry(
        value: 'report',
        label: 'Report',
        icon: Icons.error_outline_rounded,
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.34),
            child: Stack(
              children: [
                Positioned(
                  left: bubbleLeft,
                  top: top,
                  width: bubbleWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: IgnorePointer(
                      child: ChatMessageBubble(message: message),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top + bubbleHeight + 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChatActionMenuPanel(
                          entries: actions,
                          onSelected: onSelected,
                        ),
                        if (showDelete) ...[
                          const Gap(12),
                          _ChatActionDeletePanel(onTap: () {
                            onSelected('delete');
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatActionMenuEntry {
  const _ChatActionMenuEntry({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _ChatActionMenuPanel extends StatelessWidget {
  const _ChatActionMenuPanel({
    required this.entries,
    required this.onSelected,
  });

  final List<_ChatActionMenuEntry> entries;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF222326).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: 146,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in entries)
              _ChatActionMenuRow(
                entry: entry,
                onTap: () => onSelected(entry.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatActionMenuRow extends StatelessWidget {
  const _ChatActionMenuRow({
    required this.entry,
    required this.onTap,
  });

  final _ChatActionMenuEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.025),
        child: SizedBox(
          height: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.label,
                    style: TextStyles.bodyLarge.copyWith(
                      color: const Color(0xFFE8E8E8),
                      fontSize: 13,
                      height: 16 / 13,
                    ),
                  ),
                ),
                Icon(
                  entry.icon,
                  color: const Color(0xFFE2E2E2),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatActionDeletePanel extends StatelessWidget {
  const _ChatActionDeletePanel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF222326).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        width: 146,
        height: 40,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: const Color(0xFFFF3040).withValues(alpha: 0.08),
            highlightColor: const Color(0xFFFF3040).withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delete',
                      style: TextStyles.bodyLarge.copyWith(
                        color: const Color(0xFFFF3040),
                        fontSize: 13,
                        height: 16 / 13,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF3040),
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatReplyDraft {
  _ChatReplyDraft({
    required this.authorLabel,
    required this.excerpt,
    this.replyToMessageId,
  });

  final String authorLabel;
  final String excerpt;
  final String? replyToMessageId;
}

class _ChatReplyComposerPanel extends StatelessWidget {
  const _ChatReplyComposerPanel({
    required this.draft,
    required this.onClose,
    required this.composer,
  });

  final _ChatReplyDraft draft;
  final VoidCallback onClose;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final excerpt = draft.excerpt.trim();
    final shortExcerpt =
        excerpt.length > 100 ? '${excerpt.substring(0, 97)}…' : excerpt;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E20).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 42,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 2,
                          margin: const EdgeInsets.fromLTRB(12, 0, 0, 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBDBDB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Reply to ${draft.authorLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.bodyMain.copyWith(
                                    color: const Color(0xFFDBDBDB),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1.12,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  shortExcerpt,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.bodyMain.copyWith(
                                    color: AppColors.textBrand
                                        .withValues(alpha: 0.72),
                                    fontSize: 12,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textBrand.withValues(alpha: 0.74),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  composer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPendingMediaStrip extends StatelessWidget {
  const _ChatPendingMediaStrip({
    required this.data,
    required this.onRemove,
  });

  final _PendingMedia data;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = data.fileName.split(RegExp(r'[/\\]')).last;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E20).withValues(alpha: 0.78),
            border: Border.all(
              color: AppColors.textBrand.withValues(alpha: 0.1),
              width: 0.6,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textBrand.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: data.isVideo
                            ? Container(
                                width: 64,
                                height: 64,
                                color: const Color(0xFF252528),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.videocam_outlined,
                                  color: AppColors.textBrand
                                      .withValues(alpha: 0.7),
                                  size: 28,
                                ),
                              )
                            : Image.memory(
                                data.bytes,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (context, _, __) => Container(
                                  width: 64,
                                  height: 64,
                                  color: const Color(0xFF252528),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textBrand
                                        .withValues(alpha: 0.7),
                                    size: 24,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Media selected',
                            style: TextStyles.bodyMain.copyWith(
                              color:
                                  AppColors.textBrand.withValues(alpha: 0.62),
                              fontSize: 12,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.bodyLarge.copyWith(
                              color: AppColors.textBrand,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onRemove,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textBrand.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
