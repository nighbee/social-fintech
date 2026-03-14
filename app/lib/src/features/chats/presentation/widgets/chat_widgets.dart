import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ChatScaffold extends StatelessWidget {
  const ChatScaffold({
    required this.child,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ChatPageBackground(child: child),
      ),
    );
  }
}

class ChatPageBackground extends StatelessWidget {
  const ChatPageBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0F1012),
            AppColors.colorff19191A,
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -80,
            left: -40,
            child: _ChatBackgroundGlow(
              size: 220,
              colors: <Color>[
                Color(0x33273466),
                Color(0x0019191A),
              ],
            ),
          ),
          const Positioned(
            top: 140,
            right: -40,
            child: _ChatBackgroundGlow(
              size: 180,
              colors: <Color>[
                Color(0x223A5C5F),
                Color(0x0019191A),
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class ChatTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatTitleAppBar({
    required this.title,
    super.key,
    this.actions,
    this.showLeading = true,
  });

  final String title;
  final List<Widget>? actions;
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.colorff19191A,
      surfaceTintColor: AppColors.colorff19191A,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showLeading
          ? IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textBrand,
              ),
            )
          : null,
      title: Text(
        title,
        style: TextStyles.titleMain.copyWith(color: AppColors.textBrand),
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ChatDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatDetailAppBar({
    required this.thread,
    super.key,
    this.actions,
  });

  final ChatThreadPreview thread;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.colorff19191A,
      surfaceTintColor: AppColors.colorff19191A,
      toolbarHeight: preferredSize.height,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.textBrand,
        ),
      ),
      title: ChatPageTitle(
        title: thread.displayName,
        subtitle: thread.rankLine,
        caption: thread.lastSeenLabel,
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class ChatConversationOverflowButton extends StatelessWidget {
  const ChatConversationOverflowButton({
    required this.onSelected,
    super.key,
  });

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Chat actions',
      onSelected: onSelected,
      color: const Color(0xFF252529),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      position: PopupMenuPosition.under,
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'forward',
          child: Text(
            'Forward message',
            style: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
          ),
        ),
        PopupMenuItem<String>(
          value: 'select',
          child: Text(
            'Select message',
            style: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
          ),
        ),
        PopupMenuItem<String>(
          value: 'block',
          child: Text(
            'Block user',
            style: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Text(
            'Delete chat',
            style: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
          ),
        ),
      ],
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: AppColors.textBrand,
      ),
    );
  }
}

class ChatPageTitle extends StatelessWidget {
  const ChatPageTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.caption,
  });

  final String title;
  final String? subtitle;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.titleHeadline.copyWith(color: AppColors.textBrand),
        ),
        if ((subtitle ?? '').isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyMain.copyWith(color: const Color(0xFFA3A3A3)),
          ),
        if ((caption ?? '').isNotEmpty)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyMain.copyWith(
              color: AppColors.textBrand.withValues(alpha: 0.56),
            ),
          ),
      ],
    );
  }
}

class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      labelText: 'Search',
      hintText: 'Search',
      onChanged: onChanged,
      showLabel: false,
      height: 48,
      borderRadius: 18,
      backgroundColor: const Color(0xFF212125),
      customBorder: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      containerPadding: const EdgeInsets.symmetric(horizontal: 16),
      contentPadding: EdgeInsets.zero,
      textStyle: TextStyles.bodyLarge.copyWith(color: AppColors.textBrand),
      hintStyle: TextStyles.bodyLarge.copyWith(
        color: AppColors.textBrand.withValues(alpha: 0.4),
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        size: 22,
        color: AppColors.textBrand.withValues(alpha: 0.56),
      ),
    );
  }
}

class ChatSectionLabel extends StatelessWidget {
  const ChatSectionLabel({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyles.bodyLarge.copyWith(
        color: const Color(0xFFA3A3A3),
        height: 1.4,
      ),
    );
  }
}

class ChatThreadCard extends StatelessWidget {
  const ChatThreadCard({
    required this.thread,
    required this.onTap,
    super.key,
  });

  final ChatThreadPreview thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 24,
        blurSigma: 24,
        padding: const EdgeInsets.all(14),
        backgroundColor: const Color(0x40222226),
        borderColor: Colors.white.withValues(alpha: 0.08),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(
              displayName: thread.displayName,
              avatarUrl: thread.avatarUrl,
              radius: 24,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.titleHeadline.copyWith(
                      color: AppColors.textBrand,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    thread.rankLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.bodyMain.copyWith(
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                  if (thread.previewText.isNotEmpty) ...[
                    const Gap(6),
                    Text(
                      thread.previewText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.textBrand.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  thread.timeLabel,
                  style: TextStyles.bodyMain.copyWith(
                    color: AppColors.textBrand.withValues(alpha: 0.48),
                  ),
                ),
                if (thread.unreadCount > 0) ...[
                  const Gap(10),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6A25C),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${thread.unreadCount}',
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.colorff19191A,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    required this.displayName,
    required this.avatarUrl,
    super.key,
    this.radius = 22,
  });

  final String displayName;
  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFD8C18A),
            Color(0xFF7C6135),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      alignment: Alignment.center,
      child: Text(
        _buildInitials(displayName),
        style: TextStyles.bodyMain.copyWith(
          color: AppColors.colorff19191A,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _buildInitials(String value) {
    final parts = value
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();
  }
}

class ChatConversationMessageList extends StatelessWidget {
  const ChatConversationMessageList({
    required this.messages,
    super.key,
    this.dateLabel = 'Yesterday',
    this.showSelectionControls = false,
    this.selectedMessageIds = const <String>{},
    this.onMessageTap,
    this.emptyState,
    this.padding,
  });

  final List<ChatMessageUiModel> messages;
  final String dateLabel;
  final bool showSelectionControls;
  final Set<String> selectedMessageIds;
  final ValueChanged<ChatMessageUiModel>? onMessageTap;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }

    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Center(child: ChatDateChip(label: dateLabel)),
        const Gap(18),
        for (final message in messages) ...[
          ChatMessageBubble(
            message: message,
            showSelectionControls: showSelectionControls,
            isSelected: selectedMessageIds.contains(message.id),
            onTap: onMessageTap == null ? null : () => onMessageTap!(message),
          ),
          const Gap(14),
        ],
      ],
    );
  }
}

class ChatDateChip extends StatelessWidget {
  const ChatDateChip({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 999,
      blurSigma: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      backgroundColor: const Color(0x3327272B),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Text(
        label,
        style: TextStyles.bodyMain.copyWith(
          color: AppColors.textBrand.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    super.key,
    this.showSelectionControls = false,
    this.isSelected = false,
    this.onTap,
  });

  final ChatMessageUiModel message;
  final bool showSelectionControls;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.direction == ChatMessageDirection.outgoing;

    return Row(
      mainAxisAlignment:
          isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showSelectionControls && !isOutgoing) ...[
          _ChatSelectionIndicator(
            isSelected: isSelected,
            onTap: onTap,
          ),
          const Gap(10),
        ],
        Flexible(
          child: GestureDetector(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isOutgoing
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            Color(0xFF7A6234),
                            Color(0xFF4E3A1C),
                          ],
                        )
                      : null,
                  color: isOutgoing ? null : const Color(0xFF26262A),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isOutgoing ? 22 : 8),
                    bottomRight: Radius.circular(isOutgoing ? 8 : 22),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isOutgoing ? 0.12 : 0.08,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.forwardedSnippet != null) ...[
                        Text(
                          'Forwarded from',
                          style: TextStyles.bodyMain.copyWith(
                            color: AppColors.textBrand.withValues(alpha: 0.64),
                          ),
                        ),
                        const Gap(6),
                        Row(
                          children: [
                            ChatAvatar(
                              displayName: message.forwardedSnippet!.senderName,
                              avatarUrl:
                                  message.forwardedSnippet!.senderAvatarUrl,
                              radius: 14,
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                message.forwardedSnippet!.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyles.bodyMain.copyWith(
                                  color: AppColors.textBrand,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Gap(10),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        const Gap(10),
                      ],
                      Text(
                        message.text,
                        style: TextStyles.bodyLarge.copyWith(
                          color: AppColors.textBrand,
                          height: 1.35,
                        ),
                      ),
                      const Gap(8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.timeLabel,
                              style: TextStyles.bodyMain.copyWith(
                                color:
                                    AppColors.textBrand.withValues(alpha: 0.58),
                              ),
                            ),
                            if (message.showSeenMark) ...[
                              const Gap(4),
                              const Icon(
                                Icons.done_all_rounded,
                                size: 15,
                                color: AppColors.colorff74afe3,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    required this.controller,
    required this.onSend,
    super.key,
    this.onAttachmentTap,
    this.onMicrophoneTap,
    this.hintText = 'Message',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onMicrophoneTap;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.colorff19191A,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _ChatComposerActionButton(
              icon: Icons.add_rounded,
              onTap: onAttachmentTap,
            ),
            const Gap(10),
            Expanded(
              child: CustomTextField(
                controller: controller,
                labelText: hintText,
                hintText: hintText,
                showLabel: false,
                height: 48,
                borderRadius: 24,
                backgroundColor: const Color(0xFF232327),
                customBorder: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                containerPadding: const EdgeInsets.symmetric(horizontal: 16),
                contentPadding: EdgeInsets.zero,
                textStyle: TextStyles.bodyLarge.copyWith(
                  color: AppColors.textBrand,
                ),
                hintStyle: TextStyles.bodyLarge.copyWith(
                  color: AppColors.textBrand.withValues(alpha: 0.4),
                ),
              ),
            ),
            const Gap(10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (
                BuildContext context,
                TextEditingValue value,
                Widget? child,
              ) {
                final hasText = value.text.trim().isNotEmpty;
                return _ChatComposerActionButton(
                  icon: hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                  onTap: hasText ? onSend : onMicrophoneTap,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChatCenteredStatusCard extends StatelessWidget {
  const ChatCenteredStatusCard({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      blurSigma: 22,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      backgroundColor: const Color(0x40222226),
      borderColor: Colors.white.withValues(alpha: 0.08),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyles.bodyLarge.copyWith(
          color: AppColors.textBrand,
          height: 1.35,
        ),
      ),
    );
  }
}

class ChatFooterButton extends StatelessWidget {
  const ChatFooterButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.colorff19191A,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              label,
              style: TextStyles.bodyLarge.copyWith(
                color: AppColors.textBrand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBackgroundGlow extends StatelessWidget {
  const _ChatBackgroundGlow({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _ChatSelectionIndicator extends StatelessWidget {
  const _ChatSelectionIndicator({
    required this.isSelected,
    this.onTap,
  });

  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC6A25C)
                : Colors.white.withValues(alpha: 0.18),
            width: 1.4,
          ),
          color: isSelected ? const Color(0xFFC6A25C) : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.colorff19191A,
              )
            : null,
      ),
    );
  }
}

class _ChatComposerActionButton extends StatelessWidget {
  const _ChatComposerActionButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF232327),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(
          icon,
          color: AppColors.textBrand,
          size: 22,
        ),
      ),
    );
  }
}
