import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';

class ChatDeletedPage extends StatefulWidget {
  const ChatDeletedPage({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  State<ChatDeletedPage> createState() => _ChatDeletedPageState();
}

class _ChatDeletedPageState extends State<ChatDeletedPage> {
  late final ChatThreadPreview _thread;
  late final TextEditingController _messageController;
  List<ChatMessageUiModel> _messages = <ChatMessageUiModel>[];

  @override
  void initState() {
    super.initState();
    _thread = ChatMockStore.threadById(widget.chatId);
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
          createdAt: DateTime.now(),
          outgoingReceipt: ChatOutgoingReceipt.read,
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
      backgroundVariant: ChatBackgroundVariant.thread,
      appBar: ChatDetailAppBar(thread: _thread),
      bottomNavigationBar: ChatComposerBar(
        controller: _messageController,
        onSend: _sendMessage,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: _messages.isEmpty
              ? const Center(
                  child: ChatCenteredStatusCard(
                    message: 'Send a message to start the chat',
                  ),
                )
              : ChatConversationMessageList(
                  messages: _messages,
                  padding: EdgeInsets.zero,
                ),
        ),
      ),
    );
  }
}
