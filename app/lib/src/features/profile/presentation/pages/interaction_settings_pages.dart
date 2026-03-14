import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class InteractionsPage extends StatelessWidget {
  const InteractionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Interactions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Account & System'),
          const Gap(12),
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
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;
  bool _isReadStatusEnabled = true;
  bool _isSafeModeEnabled = true;

  void _showPlaceholderMessage(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title is not available yet.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.colorff202020,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Messages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Who can send you messages'),
          const Gap(12),
          _AudienceSelectionCard(
            selected: _selectedAudience,
            onSelected: (value) {
              setState(() {
                _selectedAudience = value;
              });
            },
          ),
          const Gap(28),
          const _InteractionSectionLabel('Message preferences'),
          const Gap(12),
          _InteractionCard(
            children: [
              _InteractionToggleRow(
                title: 'Read status',
                value: _isReadStatusEnabled,
                onChanged: (value) {
                  setState(() {
                    _isReadStatusEnabled = value;
                  });
                },
              ),
              const _InteractionBodyCopy(
                'People can see when you have read their messages. They will known when you read their messages only when both of you turn this on.',
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
                onChanged: (value) {
                  setState(() {
                    _isSafeModeEnabled = value;
                  });
                },
              ),
              const _InteractionBodyCopy(
                'Sensitive content in direct messages will be hidden unless you choose to view them. Messages from potentially unsafe sources will also be moved to filtered requests.',
              ),
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
                onTap: () => _showPlaceholderMessage('Requests'),
              ),
            ],
          ),
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
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;
  bool _isFilterEnabled = true;

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Who can comment on your posts'),
          const Gap(12),
          _AudienceSelectionCard(
            selected: _selectedAudience,
            onSelected: (value) {
              setState(() {
                _selectedAudience = value;
              });
            },
          ),
          const Gap(28),
          const _InteractionSectionLabel('Comment filters'),
          const Gap(12),
          _InteractionCard(
            children: [
              _InteractionToggleRow(
                title: 'Filter unwanted comments',
                value: _isFilterEnabled,
                onChanged: (value) {
                  setState(() {
                    _isFilterEnabled = value;
                  });
                },
              ),
              const _InteractionBodyCopy(
                'People can see when you have read their messages. They will known when you read their messages only when both of you turn this on.',
              ),
            ],
          ),
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
  _InteractionAudienceOption _selectedAudience =
      _InteractionAudienceOption.everyone;

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Mentions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InteractionSectionLabel('Who can mention you'),
          const Gap(12),
          _AudienceSelectionCard(
            selected: _selectedAudience,
            onSelected: (value) {
              setState(() {
                _selectedAudience = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

class BlockedAccountsPage extends StatelessWidget {
  const BlockedAccountsPage({
    super.key,
    this.accounts = const <BlockedAccountPreview>[],
  });

  final List<BlockedAccountPreview> accounts;

  @override
  Widget build(BuildContext context) {
    return _InteractionSettingsScaffold(
      title: 'Blocked accounts',
      bodyPadding: accounts.isEmpty
          ? const EdgeInsets.fromLTRB(24, 0, 24, 24)
          : const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: accounts.isEmpty
          ? const _BlockedAccountsEmptyState()
          : Column(
              children: [
                for (var i = 0; i < accounts.length; i++) ...[
                  _BlockedAccountTile(account: accounts[i]),
                  if (i != accounts.length - 1) const Gap(12),
                ],
              ],
            ),
    );
  }
}

class BlockedAccountPreview {
  const BlockedAccountPreview({
    required this.userId,
    required this.displayName,
    required this.subtitle,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String subtitle;
  final String? avatarUrl;
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
          Transform.scale(
            scale: 0.88,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.colorffffffff,
              inactiveThumbColor: AppColors.colorffffffff,
              activeTrackColor: AppColors.colorff838383,
              inactiveTrackColor: AppColors.colorff3F3F40,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
  const _BlockedAccountTile({required this.account});

  final BlockedAccountPreview account;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D2230),
        borderRadius: BorderRadius.circular(12),
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
                  account.displayName,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorffffffff,
                    fontWeight: FontWeight.w600,
                    height: 20 / 16,
                  ),
                ),
                const Gap(2),
                Text(
                  account.subtitle,
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
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.colorff202020,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.colorff3F3F40),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
}
