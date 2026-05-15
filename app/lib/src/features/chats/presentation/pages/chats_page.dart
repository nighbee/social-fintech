import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/presentation/mappers/chat_thread_preview_mapper.dart';
import 'package:app/src/features/chats/presentation/models/chat_models.dart';
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
  bool _loading = true;
  String? _errorMessage;
  List<ChatThreadPreview> _threads = const [];

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final result = await _remote.listConversations(limit: 30);
    if (!mounted) return;
    result.fold(
      (DomainException error) {
        setState(() {
          _loading = false;
          _errorMessage = error.message;
          _threads = const [];
        });
      },
      (dto) {
        final mapped = dto.items
            .map(ChatThreadPreviewMapper.fromConversation)
            .toList(growable: false);
        setState(() {
          _loading = false;
          _errorMessage = null;
          _threads = mapped;
        });
      },
    );
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

  /// Заявки в переписку — отдельного эндпоинта пока нет.
  List<ChatThreadPreview> get _visibleRequests => const <ChatThreadPreview>[];

  List<ChatThreadPreview> get _visibleChats => _filterThreads(_threads);

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _visibleRequests;
    final visibleChats = _visibleChats;
    final query = _searchQuery.trim();

    return ChatScaffold(
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.chats),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.textBrand,
          onRefresh: _loadConversations,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
              if (_loading) ...[
                const Gap(48),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.textBrand),
                ),
              ] else if (_errorMessage != null) ...[
                const Gap(24),
                ChatCenteredStatusCard(message: _errorMessage!),
                const Gap(16),
                Align(
                  child: TextButton(
                    onPressed: _loadConversations,
                    child: Text(
                      'Retry',
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.textBrand.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                if (visibleRequests.isNotEmpty) ...[
                  const Gap(24),
                  Row(
                    children: [
                      const Expanded(
                          child: ChatSectionLabel(label: 'Requests')),
                      TextButton(
                        onPressed: () =>
                            context.pushNamed(RouteNames.chatRequests),
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
                    onTap: () async {
                      await context.pushNamed(RouteNames.chatRequests);
                      if (mounted) {
                        await _loadConversations();
                      }
                    },
                  ),
                ],
                if (visibleChats.isNotEmpty) ...[
                  const Gap(24),
                  const ChatSectionLabel(label: 'Messages'),
                  const Gap(12),
                  for (final thread in visibleChats) ...[
                    ChatThreadCard(
                      thread: thread,
                      onTap: () async {
                        await context.pushNamed(
                          RouteNames.chatConversation,
                          pathParameters: <String, String>{
                            'chatId': thread.id,
                          },
                          extra: thread,
                        );
                        if (mounted) {
                          await _loadConversations();
                        }
                      },
                    ),
                    if (thread != visibleChats.last) const Gap(12),
                  ],
                ],
                if (!_loading &&
                    _errorMessage == null &&
                    visibleChats.isEmpty &&
                    visibleRequests.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: ChatCenteredStatusCard(
                      message: query.isEmpty
                          ? 'No chats yet. Start a conversation from a profile.'
                          : 'No chats found for this search.',
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
