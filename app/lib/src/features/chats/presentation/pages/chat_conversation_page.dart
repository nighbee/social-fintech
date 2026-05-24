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
import 'package:app/src/features/chats/presentation/mappers/chat_message_api_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
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

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  IHomeRemote get _homeRemote =>
      getIt<IHomeRemote>(instanceName: 'HomeRemoteImpl');

  IProfileRemote get _profileRemote =>
      getIt<IProfileRemote>(instanceName: 'ProfileRemoteImpl');

  bool get _isRealConversation =>
      chatConversationIdLooksLikeUuid(widget.chatId.trim());

  String? _currentUserId() {
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

  String _profileUserId(ProfileState s) => s.maybeWhen(
        loaded: (ProfileViewModel vm) => vm.profile.userId.trim(),
        loading: (ProfileViewModel vm) => vm.profile.userId.trim(),
        orElse: () => '',
      );

  String _authUserId(AuthState s) => s.maybeWhen(
        authenticated: (loginEntity) => loginEntity.user.id.trim(),
        orElse: () => '',
      );

  void _remapMessagesFromRemoteDtos() {
    if (!_isRealConversation || _remoteMessageDtos.isEmpty) {
      return;
    }
    final uid = _currentUserId();
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
    _messageController.dispose();
    super.dispose();
  }

  String _replyLabelForMessage(ChatMessageUiModel m) {
    if (m.direction == ChatMessageDirection.outgoing) {
      return 'Вы';
    }
    final name = _thread.displayName.trim();
    return name.isNotEmpty ? name : 'Собеседник';
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

  RelativeRect _menuPositionFor(Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final size = overlay?.size ?? MediaQuery.sizeOf(context);
    return RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      size.width - globalPosition.dx,
      size.height - globalPosition.dy,
    );
  }

  PopupMenuItem<String> _messagePopupItem({
    required String value,
    required String label,
    required IconData icon,
    Color? color,
  }) {
    final c = color ?? AppColors.textBrand;
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        width: 130,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bodyMain.copyWith(
                  color: c,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            ),
            Icon(icon, color: c, size: 15),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessageActionsForModelAt(
    ChatMessageUiModel m,
    Offset globalPosition,
  ) async {
    final isSystem = m.messageType == 'system';
    final canCopy = _messageExcerpt(m).trim().isNotEmpty;

    final selected = await showMenu<String>(
      context: context,
      position: _menuPositionFor(globalPosition),
      color: const Color(0xFF2D2D31),
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      items: <PopupMenuEntry<String>>[
        if (!isSystem)
          _messagePopupItem(
            value: 'reply',
            label: 'Reply',
            icon: Icons.reply_rounded,
          ),
        _messagePopupItem(
          value: 'forward',
          label: 'Forward',
          icon: Icons.forward_rounded,
        ),
        if (canCopy)
          _messagePopupItem(
            value: 'copy',
            label: 'Copy',
            icon: Icons.copy_rounded,
          ),
        if (!isSystem)
          _messagePopupItem(
            value: 'pin',
            label: 'Pin',
            icon: Icons.push_pin_outlined,
          ),
        if (!isSystem)
          _messagePopupItem(
            value: 'delete',
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFFF3B45),
          ),
        const PopupMenuDivider(height: 1),
        _messagePopupItem(
          value: 'select',
          label: 'Select',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    );

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
      case 'pin':
        unawaited(_pinMessageFromMenu(m.id));
        return;
      case 'delete':
        await _openDeleteMessageMenu(m, globalPosition);
        return;
      case 'select':
        context.pushNamed(
          RouteNames.chatConversationSelect,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
    }
  }

  Future<void> _openDeleteMessageMenu(
    ChatMessageUiModel m,
    Offset globalPosition,
  ) async {
    final partner = _thread.displayName.trim().isEmpty
        ? 'partner'
        : _thread.displayName.trim();
    final selected = await showMenu<String>(
      context: context,
      position: _menuPositionFor(globalPosition + const Offset(118, 98)),
      color: const Color(0xFF252529),
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      items: <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'both',
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: 122,
            child: Text(
              'Delete for\n$partner',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.bodyMain.copyWith(
                color: const Color(0xFFFF3B45),
                fontSize: 11,
                height: 1.15,
              ),
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'me',
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Delete for me',
            style: TextStyles.bodyMain.copyWith(
              color: const Color(0xFFFF3B45),
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    unawaited(_deleteMessageApi(m.id, forBoth: selected == 'both'));
  }

  Future<void> _pinMessageFromMenu(String messageId) async {
    if (!mounted || !_isRealConversation) {
      return;
    }
    final res = await _remote.pinMessage(
      conversationId: widget.chatId.trim(),
      messageId: messageId,
    );
    if (!mounted) {
      return;
    }
    res.fold(
      (DomainException e) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message))),
      (_) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение закреплено')),
        );
        await _loadPinnedMessages();
      },
    );
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

  Future<void> _loadRemoteMessages() async {
    setState(() {
      _loadingRemote = true;
      _remoteError = null;
    });
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
            currentUserId: _currentUserId(),
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
    await ImagePickerHelper.showMediaPicker(
      context: context,
      onMediaSelected: (Uint8List bytes, String fileName) {
        if (!mounted) {
          return;
        }
        setState(() =>
            _pendingMedia = _PendingMedia(bytes: bytes, fileName: fileName));
      },
      onError: (String message) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
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
    final upload = await _homeRemote.uploadFeedMedia(
      UploadFeedMediaRequest(bytes: bytes, fileName: fileName),
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
          _pendingMedia = null;
          _replyDraft = null;
          _remoteMessageDtos = [..._remoteMessageDtos, dto];
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: _currentUserId(),
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
          _replyDraft = null;
          _remoteMessageDtos = [..._remoteMessageDtos, dto];
          _messages = ChatMessageApiMapper.toUiModels(
            _remoteMessageDtos,
            currentUserId: _currentUserId(),
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
          ChatConversationOverflowButton(onSelected: _handleMenuSelection),
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
                    _ChatReplyDraftStrip(
                      draft: _replyDraft!,
                      onClose: () {
                        if (_sending) {
                          return;
                        }
                        setState(() => _replyDraft = null);
                      },
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
                            child: const Center(
                              child: ChatCenteredStatusCard(
                                message:
                                    'Отправьте сообщение, чтобы начать чат',
                              ),
                            ),
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
        _remapMessagesFromRemoteDtos();
      },
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (AuthState previous, AuthState current) =>
            _remoteMessageDtos.isNotEmpty &&
            _authUserId(previous) != _authUserId(current),
        listener: (BuildContext context, AuthState state) {
          _remapMessagesFromRemoteDtos();
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

class _ChatReplyDraftStrip extends StatelessWidget {
  const _ChatReplyDraftStrip({
    required this.draft,
    required this.onClose,
  });

  final _ChatReplyDraft draft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final excerpt = draft.excerpt.trim();
    final shortExcerpt =
        excerpt.length > 100 ? '${excerpt.substring(0, 97)}…' : excerpt;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(68, 8, 68, 0),
        child: SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.055),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF74AFE3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Gap(9),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'Reply to ${draft.authorLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.bodyMain.copyWith(
                            color: const Color(0xFFB9BEC7),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.15,
                          ),
                        ),
                        const Gap(3),
                        Text(
                          shortExcerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.textBrand,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textBrand.withValues(alpha: 0.68),
                    size: 18,
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
            color: AppColors.textBrand.withValues(alpha: 0.05),
            border: Border(
              left: BorderSide(
                color: AppColors.textBrand.withValues(alpha: 0.3),
                width: 3,
              ),
              top: BorderSide(
                color: AppColors.textBrand.withValues(alpha: 0.1),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: AppColors.textBrand.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
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
                            color: AppColors.textBrand.withValues(alpha: 0.7),
                            size: 28,
                          ),
                        )
                      : Image.memory(
                          data.bytes,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
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
                      'Добавить подпись',
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.textBrand.withValues(alpha: 0.55),
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
      ),
    );
  }
}
