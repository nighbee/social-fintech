import 'package:app/src/core/router/router.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatSelectMessagePage extends StatefulWidget {
  const ChatSelectMessagePage({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  State<ChatSelectMessagePage> createState() => _ChatSelectMessagePageState();
}

class _ChatSelectMessagePageState extends State<ChatSelectMessagePage> {
  late final ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  late final List<ChatMessageUiModel> _messages;
  late Set<String> _selectedMessageIds;

  @override
  void initState() {
    super.initState();
    _thread = ChatMockStore.threadById(widget.chatId);
    _messageController = TextEditingController();
    _messages = List<ChatMessageUiModel>.from(
      ChatMockStore.baseMessages(widget.chatId),
    );
    _selectedMessageIds = _messages.isEmpty
        ? <String>{}
        : <String>{_messages.first.id};
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
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ChatScaffold(
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
        child: ChatConversationMessageList(
          messages: _messages,
          showSelectionControls: true,
          selectedMessageIds: _selectedMessageIds,
          onMessageTap: _toggleMessage,
        ),
      ),
    );
  }
}
