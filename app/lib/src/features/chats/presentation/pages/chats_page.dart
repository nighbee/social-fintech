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
  _ChatListTab _selectedTab = _ChatListTab.inbox;
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

  List<ChatThreadPreview> get _visibleRequests {
    return _filterThreads(
      _threads.where((thread) => thread.isRequest).toList(growable: false),
    );
  }

  List<ChatThreadPreview> get _visibleChats {
    return _filterThreads(
      _threads.where((thread) => !thread.isRequest).toList(growable: false),
    );
  }

  List<ChatThreadPreview> get _activeThreads {
    return switch (_selectedTab) {
      _ChatListTab.inbox => _visibleChats,
      _ChatListTab.requests => _filterThreads(_visibleRequests),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _visibleRequests;
    final activeThreads = _activeThreads;
    final query = _searchQuery.trim();

    return ChatScaffold(
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.chats),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.textBrand,
          onRefresh: _loadConversations,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            children: [
              ChatSearchField(
                controller: _searchController,
                onChanged: (String value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const Gap(28),
              _ChatListTabs(
                selectedTab: _selectedTab,
                onSelected: (tab) {
                  setState(() {
                    _selectedTab = tab;
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
                if (activeThreads.isNotEmpty) ...[
                  const Gap(28),
                  for (final thread in activeThreads) ...[
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
                    if (thread != activeThreads.last) const Gap(12),
                  ],
                ],
                if (!_loading &&
                    _errorMessage == null &&
                    activeThreads.isEmpty &&
                    (visibleRequests.isEmpty ||
                        _selectedTab == _ChatListTab.requests)) ...[
                  if (query.isEmpty && _selectedTab == _ChatListTab.requests)
                    const _NoRequestsEmptyState()
                  else
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

enum _ChatListTab {
  inbox('Inbox'),
  requests('Requests');

  const _ChatListTab(this.label);

  final String label;
}

class _ChatListTabs extends StatelessWidget {
  const _ChatListTabs({
    required this.selectedTab,
    required this.onSelected,
  });

  final _ChatListTab selectedTab;
  final ValueChanged<_ChatListTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in _ChatListTab.values) ...[
          _ChatListTabButton(
            label: tab.label,
            selected: tab == selectedTab,
            onTap: () => onSelected(tab),
          ),
          if (tab != _ChatListTab.values.last) const Gap(10),
        ],
      ],
    );
  }
}

class _ChatListTabButton extends StatelessWidget {
  const _ChatListTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(6);
    final width = label == 'Inbox' ? 95.0 : 108.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.025),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: width,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDBDBDB) : Colors.transparent,
            borderRadius: borderRadius,
            border: Border.all(
              color: const Color(0xFFCACACA),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 18 / 14,
              color:
                  selected ? AppColors.colorff19191A : const Color(0xFFDBDBDB),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoRequestsEmptyState extends StatelessWidget {
  const _NoRequestsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 154),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/no_request.png',
              width: 76,
              height: 76,
              fit: BoxFit.contain,
            ),
            const Gap(18),
            Text(
              'No requests',
              style: TextStyles.titleMain.copyWith(
                color: AppColors.textBrand,
                fontSize: 20,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
