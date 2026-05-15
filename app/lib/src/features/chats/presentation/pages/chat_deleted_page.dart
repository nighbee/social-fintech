import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';

class ChatDeletedPage extends StatefulWidget {
  const ChatDeletedPage({
    required this.chatId,
    this.threadPreview,
    super.key,
  });

  final String chatId;
  final ChatThreadPreview? threadPreview;

  @override
  State<ChatDeletedPage> createState() => _ChatDeletedPageState();
}

class _ChatDeletedPageState extends State<ChatDeletedPage> {
  late final ChatThreadPreview _thread;
  late final TextEditingController _messageController;

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
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    _messageController.clear();
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
          child: Center(
            child: Text(
              'Удаление чата из списка будет через API. Здесь пока заглушка.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.textBrand.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
