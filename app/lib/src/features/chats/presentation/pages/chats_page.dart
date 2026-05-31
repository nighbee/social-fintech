import 'dart:async';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/chats/data/sources/remote/i_chats_remote.dart';
import 'package:app/src/features/chats/data/services/chat_realtime_service.dart';
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
  StreamSubscription<ChatRealtimeEvent>? _realtimeSubscription;
  Timer? _realtimeReloadDebounce;

  IChatsRemote get _remote =>
      getIt<IChatsRemote>(instanceName: 'ChatsRemoteImpl');

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _realtimeSubscription = ChatRealtimeService.instance.events.listen(
      _handleRealtimeEvent,
    );
    _loadConversations();
  }

  @override
  void dispose() {
    _realtimeReloadDebounce?.cancel();
    _realtimeSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    switch (event.type) {
      case 'message.new':
      case 'conversation.request_accepted':
      case 'conversation.request_declined':
      case 'conversation.deleted':
      case 'conversation.cleared':
        _scheduleRealtimeReload();
        return;
    }
  }

  void _scheduleRealtimeReload() {
    _realtimeReloadDebounce?.cancel();
    _realtimeReloadDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(_loadConversations(silent: true));
      }
    });
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    final result = await _remote.listConversations(limit: 30);
    if (!mounted) return;
    result.fold(
      (DomainException error) {
        if (silent) {
          return;
        }
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
          if (!silent) {
            _loading = false;
          }
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
      _threads
          .where((thread) => thread.isRequest && !_isDeclined(thread))
          .toList(growable: false),
    );
  }

  List<ChatThreadPreview> get _visibleChats {
    return _filterThreads(
      _threads
          .where((thread) => !thread.isRequest && !_isDeclined(thread))
          .toList(growable: false),
    );
  }

  bool _isDeclined(ChatThreadPreview thread) {
    final status = thread.requestStatus.trim().toLowerCase();
    return status == 'declined' || status == 'rejected';
  }

  Future<void> _handleRequestAction(
    ChatThreadPreview thread, {
    required bool accept,
  }) async {
    final result = accept
        ? await _remote.acceptConversationRequest(conversationId: thread.id)
        : await _remote.declineConversationRequest(conversationId: thread.id);
    if (!mounted) {
      return;
    }
    result.fold(
      (DomainException error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      },
      (_) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(accept ? 'Request accepted' : 'Request declined')),
        );
        await _loadConversations();
      },
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
                      onAcceptRequest: thread.isRequest
                          ? () => _handleRequestAction(thread, accept: true)
                          : null,
                      onDeclineRequest: thread.isRequest
                          ? () => _handleRequestAction(thread, accept: false)
                          : null,
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
