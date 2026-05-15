import 'dart:async';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/chats/data/models/message_dto.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_message_api_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatSelectMessagePage extends StatefulWidget {
  const ChatSelectMessagePage({
    required this.chatId,
    this.threadPreview,
    super.key,
  });

  final String chatId;
  final ChatThreadPreview? threadPreview;

  @override
  State<ChatSelectMessagePage> createState() => _ChatSelectMessagePageState();
}

class _ChatSelectMessagePageState extends State<ChatSelectMessagePage> {
  late ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  List<ChatMessageUiModel> _messages = <ChatMessageUiModel>[];
  late Set<String> _selectedMessageIds;
  bool _loading = true;
  String? _error;

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
    _selectedMessageIds = <String>{};
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
        });
      },
      (data) {
        final uid = _currentUserId();
        setState(() {
          _loading = false;
          _error = null;
          final list = List<MessageDto>.from(data.items);
          _messages = uid == null || uid.isEmpty
              ? <ChatMessageUiModel>[]
              : ChatMessageApiMapper.toUiModels(list, currentUserId: uid);
          if (_messages.isNotEmpty) {
            _selectedMessageIds = <String>{_messages.first.id};
          }
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
        context.pushNamed(
          RouteNames.chatConversationForward,
          pathParameters: <String, String>{'chatId': widget.chatId},
          extra: _thread,
        );
        return;
      case 'select':
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

  void _toggleMessage(ChatMessageUiModel message) {
    if (message.direction == ChatMessageDirection.outgoing) {
      return;
    }

    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds = Set<String>.from(_selectedMessageIds)
          ..remove(message.id);
      } else {
        _selectedMessageIds = Set<String>.from(_selectedMessageIds)
          ..add(message.id);
      }
    });
  }

  void _sendMessage() {
    _messageController.clear();
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
                : ChatConversationMessageList(
                    messages: _messages,
                    showSelectionControls: true,
                    selectedMessageIds: _selectedMessageIds,
                    onMessageTap: _toggleMessage,
                  ),
      ),
    );
  }
}
