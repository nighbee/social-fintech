import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_widgets.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatThreadPreview> _filterThreads(List<ChatThreadPreview> threads) {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return threads;
    }

    return threads.where((ChatThreadPreview thread) {
      return thread.displayName.toLowerCase().contains(normalizedQuery) ||
          thread.rankLine.toLowerCase().contains(normalizedQuery) ||
          thread.previewText.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _filterThreads(ChatMockStore.requestThreads);
    final visibleChats = _filterThreads(ChatMockStore.recentThreads);
    final hasMatches = visibleRequests.isNotEmpty || visibleChats.isNotEmpty;

    return ChatScaffold(
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.chats),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            ChatSearchField(
              controller: _searchController,
              onChanged: (String value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            if (visibleRequests.isNotEmpty) ...[
              const Gap(24),
              Row(
                children: [
                  const Expanded(child: ChatSectionLabel(label: 'Requests')),
                  TextButton(
                    onPressed: () => context.pushNamed(RouteNames.chatRequests),
                    child: Text(
                      'See all',
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.textBrand.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              ChatThreadCard(
                thread: visibleRequests.first,
                onTap: () => context.pushNamed(RouteNames.chatRequests),
              ),
            ],
            if (visibleChats.isNotEmpty) ...[
              const Gap(24),
              const ChatSectionLabel(label: 'Messages'),
              const Gap(12),
              for (final thread in visibleChats) ...[
                ChatThreadCard(
                  thread: thread,
                  onTap: () {
                    context.pushNamed(
                      RouteNames.chatConversation,
                      pathParameters: <String, String>{
                        'chatId': thread.id,
                      },
                    );
                  },
                ),
                if (thread != visibleChats.last) const Gap(12),
              ],
            ],
            if (!hasMatches)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: ChatCenteredStatusCard(
                  message: 'No chats found for this search.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
