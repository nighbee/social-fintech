import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatBlockedPage extends StatelessWidget {
  const ChatBlockedPage({
    required this.chatId,
    this.threadPreview,
    super.key,
  });

  final String chatId;
  final ChatThreadPreview? threadPreview;

  @override
  Widget build(BuildContext context) {
    final thread = threadPreview ??
        ChatThreadPreview(
          id: chatId.trim(),
          displayName: 'Чат',
          rankLine: '',
          lastSeenLabel: '',
          timeLabel: '',
          avatarUrl: '',
        );

    return ChatScaffold(
      backgroundVariant: ChatBackgroundVariant.thread,
      appBar: ChatDetailAppBar(thread: thread),
      bottomNavigationBar: ChatFooterButton(
        label: 'Разблокировать',
        onTap: () => context.pop(),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Пользователь заблокирован. Разблокировка будет через API, '
              'когда подключим экран к бэкенду.',
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
