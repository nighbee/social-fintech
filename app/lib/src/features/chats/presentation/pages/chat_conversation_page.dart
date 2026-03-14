import 'package:app/src/core/router/router.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  late final ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  late List<ChatMessageUiModel> _messages;

  @override
  void initState() {
    super.initState();
    _thread = ChatMockStore.threadById(widget.chatId);
    _messageController = TextEditingController();
    _messages = List<ChatMessageUiModel>.from(
      ChatMockStore.baseMessages(widget.chatId),
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages = [
        ..._messages,
        ChatMessageUiModel(
          id: ChatMockStore.newMessageId(widget.chatId, _messages.length + 1),
          direction: ChatMessageDirection.outgoing,
          text: text,
          timeLabel: _buildTimeLabel(),
          showSeenMark: true,
        ),
      ];
    });

    _messageController.clear();
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
        child: ChatConversationMessageList(messages: _messages),
      ),
    );
  }
}
