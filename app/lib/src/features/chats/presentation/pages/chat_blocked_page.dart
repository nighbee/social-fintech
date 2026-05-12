import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatBlockedPage extends StatelessWidget {
  const ChatBlockedPage({
    required this.chatId,
    super.key,
  });

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final thread = ChatMockStore.threadById(chatId);

    return ChatScaffold(
      backgroundVariant: ChatBackgroundVariant.thread,
      appBar: ChatDetailAppBar(thread: thread),
      bottomNavigationBar: ChatFooterButton(
        label: 'Unblock',
        onTap: () => context.pop(),
      ),
      child: SafeArea(
        top: false,
        child: ChatConversationMessageList(
          messages: ChatMockStore.baseMessages(chatId),
        ),
      ),
    );
  }
}
