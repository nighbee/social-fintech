import 'dart:async';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_message_api_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class ChatForwardMessagePage extends StatefulWidget {
  const ChatForwardMessagePage({
    required this.chatId,
    this.threadPreview,
    super.key,
  });

  final String chatId;
  final ChatThreadPreview? threadPreview;

  @override
  State<ChatForwardMessagePage> createState() => _ChatForwardMessagePageState();
}

class _ChatForwardMessagePageState extends State<ChatForwardMessagePage> {
  late ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  List<ChatMessageUiModel> _messages = <ChatMessageUiModel>[];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  List<MessageDto> _remoteDtos = <MessageDto>[];

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  String? _currentUserId() {
    return getIt<AuthBloc>().state.maybeWhen(
          authenticated: (e) => e.user.id.trim().isEmpty ? null : e.user.id.trim(),
          orElse: () => null,
        );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    if (!chatConversationIdLooksLikeUuid(widget.chatId.trim())) {
      setState(() {
        _loading = false;
        _error = 'Некорректный идентификатор чата';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _remote.listMessages(
      conversationId: widget.chatId.trim(),
      limit: 50,
    );
    if (!mounted) {
      return;
    }
    result.fold(
      (DomainException e) {
        setState(() {
          _loading = false;
          _error = e.message;
          _messages = <ChatMessageUiModel>[];
          _remoteDtos = <MessageDto>[];
        });
      },
      (data) {
        final uid = _currentUserId();
        setState(() {
          _loading = false;
          _error = null;
          _remoteDtos = List<MessageDto>.from(data.items);
          _messages = uid == null || uid.isEmpty
              ? <ChatMessageUiModel>[]
              : ChatMessageApiMapper.toUiModels(_remoteDtos, currentUserId: uid);
        });
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'forward':
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    if (!chatConversationIdLooksLikeUuid(widget.chatId.trim())) {
      return;
    }
    setState(() => _sending = true);
    final result = await _remote.sendMessage(
      conversationId: widget.chatId.trim(),
      body: text,
      idempotencyKey: const Uuid().v4(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    result.fold(
      (DomainException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
      (MessageDto dto) {
        _messageController.clear();
        setState(() {
          _remoteDtos = [..._remoteDtos, dto];
          final uid = _currentUserId();
          if (uid != null && uid.isNotEmpty) {
            _messages = [
              ..._messages,
              ChatMessageApiMapper.toUiModel(dto, currentUserId: uid),
            ];
          }
        });
      },
    );
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
      bottomNavigationBar: ChatComposerBar(
        controller: _messageController,
        onSend: _sendMessage,
        sendEnabled: !_sending,
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyles.bodyLarge.copyWith(
                          color: AppColors.textBrand.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  )
                : ChatConversationMessageList(messages: _messages),
      ),
    );
  }
}
