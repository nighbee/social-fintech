import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChatRequestsPage extends StatelessWidget {
  const ChatRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = ChatMockStore.requestThreads;
    final requestThread = requests.isNotEmpty ? requests.first : null;

    return ChatScaffold(
      appBar: ChatTitleAppBar(
        title: 'Requests',
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textBrand,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.chats),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ChatSectionLabel(label: 'Requests'),
            const Gap(12),
            if (requestThread != null) ...[
              ChatThreadCard(
                thread: requestThread,
                onTap: () {
                  context.pushNamed(
                    RouteNames.chatConversation,
                    pathParameters: <String, String>{
                      'chatId': requestThread.id,
                    },
                  );
                },
              ),
              const Gap(24),
            ],
            Text(
              requestThread == null
                  ? 'No message requests right now.'
                  : 'Messages from people you don\'t follow appear here.',
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.textBrand.withValues(alpha: 0.56),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
