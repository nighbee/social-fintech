import 'dart:async';

import 'package:app/src/core/exceptions/domain_exception.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/neutral_track_switch.dart';
import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

void _showInteractionError(BuildContext context, DomainException e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.colorff202020,
    ),
  );
}

/// Лёгкое уведомление снизу при ошибке загрузки (без блокировки экрана).
void _showLoadFailedSnack(BuildContext context, String detail) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Couldn\'t load. $detail',
        style: TextStyles.bodyMain.copyWith(
          color: AppColors.colorffffffff,
          fontSize: 14,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.colorff202020,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}

class InteractionsPage extends StatelessWidget {
  const InteractionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Interactions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InteractionCard(
            children: [
              _InteractionMenuRow(
                title: 'Messages',
                onTap: () =>
                    context.pushNamed(RouteNames.profileInteractionMessages),
              ),
              _InteractionMenuRow(
                title: 'Comments',
                onTap: () =>
                    context.pushNamed(RouteNames.profileInteractionComments),
              ),
              _InteractionMenuRow(
                title: 'Mentions',
                onTap: () =>
                    context.pushNamed(RouteNames.profileInteractionMentions),
              ),
              _InteractionMenuRow(
                title: 'Blocked accounts',
                onTap: () =>
                    context.pushNamed(RouteNames.profileBlockedAccounts),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessagesInteractionPage extends StatefulWidget {
  const MessagesInteractionPage({super.key});

  @override
  State<MessagesInteractionPage> createState() =>
      _MessagesInteractionPageState();
}

class _MessagesInteractionPageState extends State<MessagesInteractionPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  static const Duration _patchDebounce = Duration(milliseconds: 500);

  bool _loading = true;
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;
  bool _isReadStatusEnabled = true;
  /// Пока нет ответа сервера — off.
  bool _isSafeModeEnabled = false;
  _InteractionAudienceOption _confirmedAudience =
      _InteractionAudienceOption.everyone;
  bool _confirmedReadStatusEnabled = true;
  bool _confirmedSafeModeEnabled = false;
  Timer? _patchTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _remote.getMessagesSettings();
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _loading = false);
        _showLoadFailedSnack(context, e.message);
      },
      (dto) {
        setState(() {
          _loading = false;
          _selectedAudience =
              _InteractionAudienceOption.fromApi(dto.whoCanMessage);
          _isReadStatusEnabled = dto.readStatus;
          _isSafeModeEnabled = dto.safeMode;
          _confirmedAudience = _selectedAudience;
          _confirmedReadStatusEnabled = _isReadStatusEnabled;
          _confirmedSafeModeEnabled = _isSafeModeEnabled;
        });
      },
    );
  }

  @override
  void dispose() {
    _patchTimer?.cancel();
    super.dispose();
  }

  void _scheduleMessagesPatch() {
    _patchTimer?.cancel();
    _patchTimer = Timer(_patchDebounce, () async {
      final result = await _remote.patchMessagesSettings(
        whoCanMessage: _selectedAudience.apiValue,
        readStatus: _isReadStatusEnabled,
        safeMode: _isSafeModeEnabled,
      );
      if (!mounted) return;
      result.fold((e) {
        setState(() {
          _selectedAudience = _confirmedAudience;
          _isReadStatusEnabled = _confirmedReadStatusEnabled;
          _isSafeModeEnabled = _confirmedSafeModeEnabled;
        });
        _showInteractionError(context, e);
      }, (_) {
        _confirmedAudience = _selectedAudience;
        _confirmedReadStatusEnabled = _isReadStatusEnabled;
        _confirmedSafeModeEnabled = _isSafeModeEnabled;
      });
    });
  }

  Future<void> _patchAudience(_InteractionAudienceOption value) async {
    setState(() => _selectedAudience = value);
    _scheduleMessagesPatch();
  }

  Future<void> _patchReadStatus(bool value) async {
    setState(() => _isReadStatusEnabled = value);
    _scheduleMessagesPatch();
  }

  Future<void> _patchSafeMode(bool value) async {
    setState(() => _isSafeModeEnabled = value);
    _scheduleMessagesPatch();
    if (value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.pushNamed(RouteNames.profileMessageFilteredKeywords);
      });
    }
  }

  void _openFilteredKeywords() {
    context.pushNamed(RouteNames.profileMessageFilteredKeywords);
  }

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Messages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            const _InteractionSectionLabel('Who can send you messages'),
            const Gap(12),
            _AudienceSelectionCard(
              selected: _selectedAudience,
              onSelected: _patchAudience,
            ),
            const Gap(28),
            const _InteractionSectionLabel('Message preferences'),
            const Gap(12),
            _InteractionCard(
              children: [
                _InteractionToggleRow(
                  title: 'Read status',
                  value: _isReadStatusEnabled,
                  onChanged: _patchReadStatus,
                ),
                const _InteractionBodyCopy(
                  'People can see when you have read their messages. They will know when you read their messages only when both of you turn this on.',
                ),
              ],
            ),
            const Gap(28),
            const _InteractionSectionLabel('Safety tools'),
            const Gap(12),
            _InteractionCard(
              children: [
                _InteractionToggleRow(
                  title: 'Safe mode',
                  value: _isSafeModeEnabled,
                  onChanged: _patchSafeMode,
                ),
                const _InteractionBodyCopy(
                  'Sensitive content in direct messages will be hidden unless you choose to view them. Messages from potentially unsafe sources will also be moved to filtered requests.',
                ),
                if (_isSafeModeEnabled) ...[
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.colorff2A2A2B,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _InteractionMenuRow(
                    title: 'Filtered keywords',
                    onTap: _openFilteredKeywords,
                  ),
                ],
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.colorff2A2A2B,
                  indent: 16,
                  endIndent: 16,
                ),
                _InteractionMenuRow(
                  title: 'Other on BrightBund',
                  trailingText: 'Requests',
                  onTap: () {
                    context.go(RoutePaths.chats);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CommentsInteractionPage extends StatefulWidget {
  const CommentsInteractionPage({super.key});

  @override
  State<CommentsInteractionPage> createState() =>
      _CommentsInteractionPageState();
}

class _CommentsInteractionPageState extends State<CommentsInteractionPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  static const Duration _patchDebounce = Duration(milliseconds: 500);

  bool _loading = true;
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;
  bool _isFilterEnabled = false;
  _InteractionAudienceOption _confirmedAudience =
      _InteractionAudienceOption.everyone;
  bool _confirmedFilterEnabled = false;
  Timer? _patchTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _remote.getCommentsSettings();
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _loading = false);
        _showInteractionError(context, e);
      },
      (dto) {
        setState(() {
          _loading = false;
          _selectedAudience =
              _InteractionAudienceOption.fromApi(dto.whoCanComment);
          _isFilterEnabled = dto.filterUnwanted;
          _confirmedAudience = _selectedAudience;
          _confirmedFilterEnabled = _isFilterEnabled;
        });
      },
    );
  }

  @override
  void dispose() {
    _patchTimer?.cancel();
    super.dispose();
  }

  void _scheduleCommentsPatch() {
    _patchTimer?.cancel();
    _patchTimer = Timer(_patchDebounce, () async {
      final result = await _remote.patchCommentsSettings(
        whoCanComment: _selectedAudience.apiValue,
        filterUnwanted: _isFilterEnabled,
      );
      if (!mounted) return;
      result.fold((e) {
        setState(() {
          _selectedAudience = _confirmedAudience;
          _isFilterEnabled = _confirmedFilterEnabled;
        });
        _showInteractionError(context, e);
      }, (_) {
        _confirmedAudience = _selectedAudience;
        _confirmedFilterEnabled = _isFilterEnabled;
      });
    });
  }

  Future<void> _patchAudience(_InteractionAudienceOption value) async {
    setState(() => _selectedAudience = value);
    _scheduleCommentsPatch();
  }

  Future<void> _patchFilter(bool value) async {
    setState(() => _isFilterEnabled = value);
    _scheduleCommentsPatch();
  }

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Who can comment on your posts'),
          const Gap(12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _AudienceSelectionCard(
              selected: _selectedAudience,
              onSelected: _patchAudience,
            ),
            const Gap(28),
            const _InteractionSectionLabel('Comment filters'),
            const Gap(12),
            _InteractionCard(
              children: [
                _InteractionToggleRow(
                  title: 'Filter unwanted comments',
                  value: _isFilterEnabled,
                  onChanged: _patchFilter,
                ),
                const _InteractionBodyCopy(
                  'Comments that match your filters may be hidden until you review them. You can adjust this if you want to see everything by default.',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class MentionsInteractionPage extends StatefulWidget {
  const MentionsInteractionPage({super.key});

  @override
  State<MentionsInteractionPage> createState() =>
      _MentionsInteractionPageState();
}

class _MentionsInteractionPageState extends State<MentionsInteractionPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  static const Duration _patchDebounce = Duration(milliseconds: 500);

  bool _loading = true;
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;
  _InteractionAudienceOption _confirmedAudience =
      _InteractionAudienceOption.everyone;
  Timer? _patchTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _remote.getMentionsSettings();
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _loading = false);
        _showInteractionError(context, e);
      },
      (dto) {
        setState(() {
          _loading = false;
          _selectedAudience =
              _InteractionAudienceOption.fromApi(dto.whoCanMention);
          _confirmedAudience = _selectedAudience;
        });
      },
    );
  }

  @override
  void dispose() {
    _patchTimer?.cancel();
    super.dispose();
  }

  void _scheduleMentionsPatch() {
    _patchTimer?.cancel();
    _patchTimer = Timer(_patchDebounce, () async {
      final result = await _remote.patchMentionsSettings(
        whoCanMention: _selectedAudience.apiValue,
      );
      if (!mounted) return;
      result.fold((e) {
        setState(() {
          _selectedAudience = _confirmedAudience;
        });
        _showInteractionError(context, e);
      }, (_) {
        _confirmedAudience = _selectedAudience;
      });
    });
  }

  Future<void> _patchAudience(_InteractionAudienceOption value) async {
    setState(() => _selectedAudience = value);
    _scheduleMentionsPatch();
  }

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Mentions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Who can mention you'),
          const Gap(12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            _AudienceSelectionCard(
              selected: _selectedAudience,
              onSelected: _patchAudience,
            ),
        ],
      ),
    );
  }
}

class BlockedAccountsPage extends StatefulWidget {
  const BlockedAccountsPage({super.key});

  @override
  State<BlockedAccountsPage> createState() => _BlockedAccountsPageState();
}

class _BlockedAccountsPageState extends State<BlockedAccountsPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();

  bool _loading = true;
  List<BlockedUserItemDto> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _remote.getBlockedUsers(limit: 50);
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _loading = false);
        _showInteractionError(context, e);
      },
      (dto) {
        setState(() {
          _loading = false;
          _items = dto.items;
        });
      },
    );
  }

  Future<void> _unblock(BlockedUserItemDto account) async {
    final result = await _remote.unblockUser(account.userId);
    if (!mounted) return;
    result.fold((e) => _showInteractionError(context, e), (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final empty = !_loading && _items.isEmpty;

    return _InteractionSettingsScaffold(
      title: 'Blocked accounts',
      bodyPadding: empty
          ? const EdgeInsets.fromLTRB(24, 0, 24, 24)
          : const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : empty
              ? const _BlockedAccountsEmptyState()
              : Column(
                  children: [
                    for (var i = 0; i < _items.length; i++) ...[
                    _BlockedAccountTile(
                      account: _items[i],
                      onUnblock: () => _unblock(_items[i]),
                    ),
                    if (i != _items.length - 1) const Gap(12),
                  ],
                  ],
                ),
    );
  }
}

class FilteredKeywordsPage extends StatefulWidget {
  const FilteredKeywordsPage({super.key});

  @override
  State<FilteredKeywordsPage> createState() => _FilteredKeywordsPageState();
}

class _FilteredKeywordsPageState extends State<FilteredKeywordsPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _safeModeOn = false;

  bool _loadFailed = false;
  bool _headerToggle = true;
  List<MessageKeywordItemDto> _keywords = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _remote.getMessagesSettings();
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        _showLoadFailedSnack(context, e.message);
      },
      (dto) {
        if (!dto.safeMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            _showLoadFailedSnack(
              context,
              'Turn on Safe mode in Messages to use keyword filters.',
            );
            context.pop();
          });
          setState(() => _loading = false);
          return;
        }
        setState(() {
          _loading = false;
          _loadFailed = false;
          _safeModeOn = true;
          _keywords = List.of(dto.keywords);
        });
      },
    );
  }

  Future<void> _addKeyword() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final result = await _remote.addMessageKeyword(raw);
    if (!mounted) return;
    result.fold(
      (e) {
        setState(() => _submitting = false);
        _showInteractionError(context, e);
      },
      (_) {
        _controller.clear();
        setState(() => _submitting = false);
        _load();
      },
    );
  }

  Future<void> _removeKeyword(String id) async {
    final result = await _remote.deleteMessageKeyword(id);
    if (!mounted) return;
    result.fold((e) => _showInteractionError(context, e), (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Filtered keywords',
                        style: TextStyles.titleMain.copyWith(
                          color: AppColors.colorffffffff,
                          height: 22 / 20,
                        ),
                      ),
                    ),
                    const Gap(12),
                    NeutralTrackSwitch(
                      value: _headerToggle,
                      onChanged: (value) {
                        setState(() => _headerToggle = value);
                      },
                    ),
                  ],
                ),
                const Gap(16),
                Text(
                  'Recent messages with specified keywords on your chats will be '
                  'hidden unless you approve them.',
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorff838383,
                    fontSize: 13,
                    height: 20 / 13,
                  ),
                ),
                const Gap(24),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.colorff838383,
                      ),
                    ),
                  )
                else if (_safeModeOn || _loadFailed) ...[
                  _FigmaFilteredKeywordInputRow(
                    controller: _controller,
                    submitting: _submitting,
                    onAdd: _addKeyword,
                  ),
                  if (_keywords.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'No keywords yet — add one above.',
                        style: TextStyles.bodyMain.copyWith(
                          color: AppColors.colorff838383,
                          fontSize: 12,
                          height: 16 / 12,
                        ),
                      ),
                    ),
                  if (_keywords.isNotEmpty) const Gap(16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in _keywords)
                        _KeywordTagChip(
                          label: k.keyword,
                          onRemove: () => _removeKeyword(k.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FigmaFilteredKeywordInputRow extends StatelessWidget {
  const _FigmaFilteredKeywordInputRow({
    required this.controller,
    required this.submitting,
    required this.onAdd,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onAdd;

  static const _borderWhite = Color.fromRGBO(255, 255, 255, 1);
  static const _minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: BoxDecoration(
        color: AppColors.colorff19191A,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderWhite, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.colorffffffff,
                height: 1.25,
              ),
              cursorColor: AppColors.colorffffffff,
              // Глобальная тема задаёт filled + белый fill — явно переопределяем.
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.colorff19191A,
                hintText: 'Add keyword',
                hintStyle: TextStyles.bodyLarge.copyWith(
                  color: AppColors.colorff838383,
                  height: 1.25,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.colorff838383,
                splashFactory: NoSplash.splashFactory,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => controller.clear(),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.colorffffffff,
              disabledForegroundColor: AppColors.colorff838383,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: submitting ? null : onAdd,
            child: Text(
              'Add',
              style: TextStyles.bodyLarge.copyWith(
                color: submitting
                    ? AppColors.colorff838383
                    : AppColors.colorffffffff,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordTagChip extends StatelessWidget {
  const _KeywordTagChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyles.bodyLarge.copyWith(
              color: AppColors.colorffffffff,
              height: 1.2,
            ),
          ),
          const Gap(8),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.colorff838383,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionSettingsScaffold extends StatelessWidget {
  const _InteractionSettingsScaffold({
    required this.title,
    required this.child,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final String title;
  final Widget child;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: CustomAppBar(
        title: title,
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: bodyPadding,
          child: child,
        ),
      ),
    );
  }
}

class _InteractionSectionLabel extends StatelessWidget {
  const _InteractionSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyles.bodyLarge.copyWith(
        color: AppColors.colorff838383,
        height: 22 / 16,
      ),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  const _InteractionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _InteractionMenuRow extends StatelessWidget {
  const _InteractionMenuRow({
    required this.title,
    required this.onTap,
    this.trailingText,
  });

  final String title;
  final VoidCallback onTap;
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    height: 22 / 16,
                  ),
                ),
              ),
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorff838383,
                    height: 22 / 16,
                  ),
                ),
                const Gap(12),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.colorff838383,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudienceSelectionCard extends StatelessWidget {
  const _AudienceSelectionCard({
    required this.selected,
    required this.onSelected,
  });

  final _InteractionAudienceOption selected;
  final ValueChanged<_InteractionAudienceOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return _InteractionCard(
      children: [
        for (final option in _InteractionAudienceOption.values)
          _AudienceOptionRow(
            option: option,
            selected: option == selected,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

class _AudienceOptionRow extends StatelessWidget {
  const _AudienceOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _InteractionAudienceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    height: 22 / 16,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_rounded : Icons.circle_outlined,
                color: selected ? AppColors.colorffffffff : Colors.transparent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionToggleRow extends StatelessWidget {
  const _InteractionToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.colorffffffff,
                height: 22 / 16,
              ),
            ),
          ),
          NeutralTrackSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InteractionBodyCopy extends StatelessWidget {
  const _InteractionBodyCopy(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Text(
        text,
        style: TextStyles.bodyMain.copyWith(
          color: AppColors.colorff838383,
          fontSize: 12,
          height: 15 / 12,
        ),
      ),
    );
  }
}

class _BlockedAccountTile extends StatelessWidget {
  const _BlockedAccountTile({
    required this.account,
    required this.onUnblock,
  });

  final BlockedUserItemDto account;
  final VoidCallback onUnblock;

  String _lastActiveLabel(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Active just now';
    if (diff.inHours < 1) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 14) return 'Active ${diff.inDays}d ago';
    return 'Active ${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _lastActiveLabel(account.lastActiveAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.colorff202020,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _BlockedAccountAvatar(imageUrl: account.avatarUrl),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.username.isNotEmpty ? account.username : 'User',
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                  ),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.colorff74afe3,
                    fontSize: 12,
                    height: 15 / 12,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onUnblock,
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.colorff202020,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.colorff3F3F40),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Unblock',
                    style: TextStyles.bodyMain.copyWith(
                      color: AppColors.colorffffffff,
                      fontSize: 13,
                      height: 16 / 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedAccountAvatar extends StatelessWidget {
  const _BlockedAccountAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: AppColors.colorff202020,
        child: trimmedUrl.isEmpty
            ? const Icon(
                Icons.person_outline_rounded,
                color: AppColors.colorffffffff,
                size: 26,
              )
            : Image.network(
                trimmedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.colorffffffff,
                  size: 26,
                ),
              ),
      ),
    );
  }
}

class _BlockedAccountsEmptyState extends StatelessWidget {
  const _BlockedAccountsEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color: AppColors.colorffffffff,
              size: 78,
            ),
            const Gap(22),
            Text(
              'No blocked accounts',
              style: TextStyles.titleBig.copyWith(
                color: AppColors.colorffffffff,
              ),
            ),
            const Gap(14),
            Text(
              'Accounts you block won\'t be able to message\nyou or interact with your posts.',
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.colorff838383,
                height: 22 / 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _InteractionAudienceOption {
  everyone('Everyone'),
  noOne('No one'),
  alliesOnly('Allies only');

  const _InteractionAudienceOption(this.label);

  final String label;

  static _InteractionAudienceOption fromApi(String raw) {
    switch (raw) {
      case 'no_one':
        return _InteractionAudienceOption.noOne;
      case 'allies_only':
        return _InteractionAudienceOption.alliesOnly;
      case 'everyone':
      default:
        return _InteractionAudienceOption.everyone;
    }
  }

  String get apiValue {
    switch (this) {
      case _InteractionAudienceOption.everyone:
        return 'everyone';
      case _InteractionAudienceOption.noOne:
        return 'no_one';
      case _InteractionAudienceOption.alliesOnly:
        return 'allies_only';
    }
  }
}
