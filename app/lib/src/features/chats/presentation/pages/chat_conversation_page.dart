import 'dart:async';
import 'dart:typed_data';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_message_api_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:app/src/features/home/data/sources/remote/i_home_remote.dart';
import 'package:app/src/features/home/domain/requests/upload_feed_media_request.dart';
import 'package:app/src/features/profile/data/sources/remote/i_profile_remote.dart';
import 'package:app/src/features/profile/domain/requests/user_id_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
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

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  IHomeRemote get _homeRemote =>
      getIt<IHomeRemote>(instanceName: 'HomeRemoteImpl');

  IProfileRemote get _profileRemote =>
      getIt<IProfileRemote>(instanceName: 'ProfileRemoteImpl');

  bool get _useBackend =>
      chatConversationIdLooksLikeUuid(widget.chatId.trim());

  String? _currentUserId() {
    final fromAuth = getIt<AuthBloc>().state.maybeWhen(
          authenticated: (loginEntity) => loginEntity.user.id,
          orElse: () => null,
        );
    final authId = fromAuth?.trim();
    if (authId != null && authId.isNotEmpty) {
      return authId;
    }
    return getIt<ProfileBloc>().state.maybeWhen(
          loaded: (vm) => vm.profile.userId,
          loading: (vm) => vm.profile.userId,
          orElse: () => null,
        )?.trim();
  }

  @override
  void initState() {
    super.initState();
    _thread = widget.threadPreview ??
        (_useBackend
            ? ChatThreadPreview(
                id: widget.chatId,
                displayName: 'Chat',
                rankLine: '',
                lastSeenLabel: '',
                timeLabel: '',
                avatarUrl: '',
              )
            : ChatMockStore.threadById(widget.chatId));
    _messageController = TextEditingController();
    _messages = _useBackend
        ? <ChatMessageUiModel>[]
        : List<ChatMessageUiModel>.from(
            ChatMockStore.baseMessages(widget.chatId),
          );
    if (_useBackend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadRemoteMessages());
        unawaited(_enrichHeaderFromProfile());
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
      final rank = entity.rankTier.trim();
      final av = entity.avatarUrl.trim();
      setState(() {
        _thread = _thread.copyWith(
          displayName: dn.isNotEmpty ? dn : _thread.displayName,
          rankLine: rank.isNotEmpty ? rank : _thread.rankLine,
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

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'forward':
        context.pushNamed(
          RouteNames.chatConversationForward,
          pathParameters: <String, String>{'chatId': widget.chatId},
        );
        return;
      case 'select':
        context.pushNamed(
          RouteNames.chatConversationSelect,
          pathParameters: <String, String>{'chatId': widget.chatId},
        );
        return;
      case 'block':
        context.pushNamed(
          RouteNames.chatConversationBlocked,
          pathParameters: <String, String>{'chatId': widget.chatId},
        );
        return;
      case 'delete':
        context.pushNamed(
          RouteNames.chatConversationDeleted,
          pathParameters: <String, String>{'chatId': widget.chatId},
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
        });
      },
      (data) {
        setState(() {
          _loadingRemote = false;
          _remoteError = null;
          _messages = ChatMessageApiMapper.toUiModels(
            data.items,
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
        }
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
    if (!_useBackend || _sending) {
      return;
    }
    await ImagePickerHelper.showMediaPicker(
      context: context,
      onMediaSelected: (Uint8List bytes, String fileName) {
        if (!mounted) {
          return;
        }
        setState(() => _pendingMedia = _PendingMedia(bytes: bytes, fileName: fileName));
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
    final idempotencyKey = const Uuid().v4();
    final result = await _remote.sendMessage(
      conversationId: widget.chatId.trim(),
      body: trimmedCaption,
      idempotencyKey: idempotencyKey,
      media: _chatMediaPayload([
        (
          type: uploaded.type,
          url: uploaded.url,
          thumbnailUrl: uploaded.thumbnailUrl,
        ),
      ]),
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
          _messages = [
            ..._messages,
            ChatMessageApiMapper.toUiModel(
              dto,
              currentUserId: _currentUserId(),
            ),
          ];
        });
      },
    );
  }

  void _onMicrophoneTap() {
    if (!_useBackend) {
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

    if (_useBackend && _pendingMedia != null) {
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

    if (!_useBackend) {
      setState(() {
        _messages = [
          ..._messages,
          ChatMessageUiModel(
            id: ChatMockStore.newMessageId(widget.chatId, _messages.length + 1),
            direction: ChatMessageDirection.outgoing,
            text: text,
            timeLabel: _buildTimeLabel(),
            createdAt: DateTime.now(),
            outgoingReceipt: ChatOutgoingReceipt.read,
          ),
        ];
      });
      _messageController.clear();
      return;
    }

    setState(() => _sending = true);
    final idempotencyKey = const Uuid().v4();
    final result = await _remote.sendMessage(
      conversationId: widget.chatId.trim(),
      body: text,
      idempotencyKey: idempotencyKey,
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
          _messages = [
            ..._messages,
            ChatMessageApiMapper.toUiModel(
              dto,
              currentUserId: _currentUserId(),
            ),
          ];
        });
      },
    );
  }

  String _buildTimeLabel() {
    final now = DateTime.now();
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return ChatScaffold(
      backgroundVariant: ChatBackgroundVariant.thread,
      appBar: ChatDetailAppBar(
        thread: _thread,
        actions: [
          ChatConversationOverflowButton(onSelected: _handleMenuSelection),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_useBackend && _pendingMedia != null)
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
            hasPendingAttachment: _useBackend && _pendingMedia != null,
            onAttachmentTap: _useBackend ? _onPickAttachment : null,
            onMicrophoneTap: _useBackend ? _onMicrophoneTap : null,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _useBackend && _loadingRemote
            ? const Center(child: CircularProgressIndicator())
            : _useBackend && _remoteError != null && _messages.isEmpty
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  ),
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
      color: Colors.black.withValues(alpha: 0.42),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: data.isVideo
                  ? Container(
                      width: 72,
                      height: 72,
                      color: const Color(0xFF252528),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.videocam_outlined,
                        color: AppColors.textBrand.withValues(alpha: 0.75),
                        size: 32,
                      ),
                    )
                  : Image.memory(
                      data.bytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add a caption',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.textBrand.withValues(alpha: 0.52),
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.bodyLarge.copyWith(
                      color: AppColors.textBrand,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textBrand.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
