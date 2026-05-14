import 'dart:math' as math;

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:app/src/features/chats/presentation/models/chat_mock_models.dart';
import 'package:app/src/features/chats/presentation/styles/chat_conversation_styles.dart';
import 'package:app/src/features/chats/presentation/styles/chat_sapphire_styles.dart';
import 'package:app/src/features/chats/presentation/utils/chat_day_separator_label.dart';
import 'package:app/src/features/chats/presentation/widgets/chat_bubble_clipper.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_rank_meta_line.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Фон под [ChatScaffold]: список чатов или лента сообщений.
enum ChatBackgroundVariant {
  list,
  thread,
}

class ChatScaffold extends StatelessWidget {
  const ChatScaffold({
    required this.child,
    super.key,
    this.appBar,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
    this.backgroundVariant = ChatBackgroundVariant.list,
    this.extendBodyBehindAppBar = false,
    this.overlayBottomNavigationBar = false,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;
  final ChatBackgroundVariant backgroundVariant;

  /// Лента сообщений рисуется под полупрозрачным [appBar] (как в Figma).
  final bool extendBodyBehindAppBar;

  /// Лента уходит под композер; сам композер в слоте [Scaffold.bottomNavigationBar]
  /// с [extendBody], чтобы пузыри не перекрывали поле ввода и кнопки.
  final bool overlayBottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final bool useScaffoldOverlayComposer =
        overlayBottomNavigationBar && bottomNavigationBar != null;

    final Widget scrollOrBody;
    if (bottomNavigationBar == null) {
      scrollOrBody = child;
    } else if (useScaffoldOverlayComposer) {
      scrollOrBody = child;
    } else {
      scrollOrBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: child),
          bottomNavigationBar!,
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      extendBody: useScaffoldOverlayComposer,
      appBar: appBar,
      bottomNavigationBar: useScaffoldOverlayComposer ? bottomNavigationBar : null,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: switch (backgroundVariant) {
          ChatBackgroundVariant.list =>
            ChatPageBackground(child: scrollOrBody),
          ChatBackgroundVariant.thread =>
            ChatThreadViewportBackground(child: scrollOrBody),
        },
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
      child: child,
    );
  }
}

/// Фон ленты сообщений: тёмная база + едва заметный двухцветный mesh (макет Figma).
class ChatThreadViewportBackground extends StatelessWidget {
  const ChatThreadViewportBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: ChatConversationStyles.viewportGradient,
      ),
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              top: -88,
              left: -100,
              child: _ConversationMeshBlob(
                diameter: ChatConversationStyles.meshBlobLeftSize,
                edge: ChatConversationStyles.meshBlobLeft,
              ),
            ),
            const Positioned(
              bottom: 32,
              right: -72,
              child: _ConversationMeshBlob(
                diameter: ChatConversationStyles.meshBlobRightSize,
                edge: ChatConversationStyles.meshBlobRight,
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _ConversationMeshBlob extends StatelessWidget {
  const _ConversationMeshBlob({
    required this.diameter,
    required this.edge,
  });

  final double diameter;
  final Color edge;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[edge, Colors.transparent],
              stops: const <double>[0.0, 0.62],
            ),
          ),
        ),
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

/// Высота панели заголовка в треде ([ChatDetailAppBar]).
const double kChatDetailAppBarHeight = 72;

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
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: preferredSize.height,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: IconButton(
        onPressed: () => context.pop(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
  Size get preferredSize => const Size.fromHeight(kChatDetailAppBarHeight);
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
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: Assets.images.dots.image(
          width: 22,
          height: 22,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Подзаголовок шапки чата: строка ранга с глобусом как в профиле, иначе обычный текст (@username / Task chat).
class _ChatHeaderSubtitle extends StatelessWidget {
  const _ChatHeaderSubtitle({required this.text});

  final String text;

  bool get _useRankMeta {
    final t = text.trim();
    if (t.isEmpty) {
      return false;
    }
    if (t == 'Task chat' || t == 'Direct message') {
      return false;
    }
    if (t.startsWith('@')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_useRankMeta) {
      return ProfileRankMetaLine(rankTier: text);
    }
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyles.bodyMain.copyWith(color: const Color(0xFFA3A3A3)),
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
          _ChatHeaderSubtitle(text: subtitle!),
        if ((caption ?? '').isNotEmpty)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.bodyMain.copyWith(
              color: const Color(0xFF8B9099),
              fontSize: 12,
              height: 14 / 12,
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
      borderRadius: ChatSapphireStyles.listCornerRadius,
      backgroundColor: ChatSapphireStyles.searchFieldFill,
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

Widget _threadRankLineText(String rankLine) {
  const prefix = 'Moonstone';
  final baseStyle = TextStyles.bodyMain;
  if (!rankLine.startsWith(prefix)) {
    return Text(
      rankLine,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: baseStyle.copyWith(
        color: ChatSapphireStyles.rankLineMutedColor,
      ),
    );
  }
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: prefix,
          style: baseStyle.copyWith(
            color: ChatSapphireStyles.rankLineColor,
          ),
        ),
        TextSpan(
          text: rankLine.substring(prefix.length),
          style: baseStyle.copyWith(
            color: ChatSapphireStyles.rankLineMutedColor,
          ),
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
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
    final r = ChatSapphireStyles.listCornerRadius;
    final borderRadius = BorderRadius.circular(r);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: ChatSapphireStyles.threadCardShadows,
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ChatSapphireStyles.threadCardSapphireFill,
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ChatSapphireStyles.threadCardGlassLightFill,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: ChatSapphireStyles.threadCardBorderColor,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ChatSapphireStyles.threadCardPaddingHorizontal,
                      ChatSapphireStyles.threadCardPaddingTop,
                      ChatSapphireStyles.threadCardPaddingHorizontal,
                      ChatSapphireStyles.threadCardPaddingBottom,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChatAvatar(
                          displayName: thread.displayName,
                          avatarUrl: thread.avatarUrl,
                          radius: ChatSapphireStyles.threadCardAvatarRadius,
                          cornerRadius: ChatSapphireStyles.listCornerRadius,
                        ),
                        const Gap(ChatSapphireStyles.threadCardGapAfterAvatar),
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
                              _threadRankLineText(thread.rankLine),
                              if (thread.previewText.isNotEmpty) ...[
                                const Gap(6),
                                Text(
                                  thread.previewText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.bodyMain.copyWith(
                                    color: AppColors.textBrand
                                        .withValues(alpha: 0.82),
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
                                color:
                                    AppColors.textBrand.withValues(alpha: 0.56),
                              ),
                            ),
                            if (thread.unreadCount > 0) ...[
                              const Gap(10),
                              Container(
                                constraints: const BoxConstraints(minWidth: 22),
                                height: 22,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.textBrand,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${thread.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: TextStyles.bodyMain.copyWith(
                                    color: AppColors.colorff19191A,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    /// Если задан — аватар в списке чатов как в Figma (скруглённый квадрат).
    this.cornerRadius,
  });

  final String displayName;
  final String avatarUrl;
  final double radius;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final trimmed = avatarUrl.trim();
    final r = cornerRadius;

    Widget imageOrInitials() {
      if (trimmed.isNotEmpty) {
        return CustomNetworkImage(
          imageUrl: trimmed,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
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

    if (r != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: imageOrInitials(),
      );
    }
    return ClipOval(child: imageOrInitials());
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
    this.showSelectionControls = false,
    this.selectedMessageIds = const <String>{},
    this.onMessageTap,
    this.onMessageLongPress,
    this.emptyState,
    this.padding,
  });

  final List<ChatMessageUiModel> messages;
  final bool showSelectionControls;
  final Set<String> selectedMessageIds;
  final ValueChanged<ChatMessageUiModel>? onMessageTap;
  final ValueChanged<ChatMessageUiModel>? onMessageLongPress;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return emptyState ?? const SizedBox.shrink();
    }

    final children = <Widget>[];
    DateTime? lastDayKey;

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final local = message.createdAt;
      final dayKey = DateTime(local.year, local.month, local.day);
      if (lastDayKey == null || dayKey != lastDayKey) {
        lastDayKey = dayKey;
        if (children.isNotEmpty) {
          children.add(const Gap(10));
        }
        children.add(
          Center(child: ChatDateChip(label: chatDaySeparatorLabel(local))),
        );
        children.add(const Gap(18));
      }
      children.add(
        ChatMessageBubble(
          message: message,
          showSelectionControls: showSelectionControls,
          isSelected: selectedMessageIds.contains(message.id),
          onTap: onMessageTap == null ? null : () => onMessageTap!(message),
          onLongPress: onMessageLongPress == null
              ? null
              : () => onMessageLongPress!(message),
        ),
      );
      children.add(const Gap(14));
    }

    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: children,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ChatConversationStyles.dateChipFill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: ChatConversationStyles.dateChipBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyles.bodyMain.copyWith(
            color: AppColors.textBrand.withValues(alpha: 0.66),
          ),
        ),
      ),
    );
  }
}

class _OutgoingReadReceipts extends StatelessWidget {
  const _OutgoingReadReceipts({
    required this.read,
    this.iconColor,
  });

  final bool read;
  final Color? iconColor;

  static const Color _readBlue = Color(0xFF3A7AB8);
  static const Color _sentGrey = Color(0xFF9AA1AC);

  @override
  Widget build(BuildContext context) {
    final c = iconColor ?? (read ? _readBlue : _sentGrey);
    return SizedBox(
      width: 22,
      height: 14,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: Icon(Icons.check_rounded, size: 13, color: c),
          ),
          Positioned(
            left: 6,
            top: 0,
            child: Icon(Icons.check_rounded, size: 13, color: c),
          ),
        ],
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
    this.onLongPress,
  });

  final ChatMessageUiModel message;
  final bool showSelectionControls;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || ok) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open link')),
    );
  }

  EdgeInsets _bubblePadding(ChatMessageUiModel m) {
    final hasMedia = m.media.isNotEmpty;
    final plain = m.text.trim().isEmpty && m.forwardedSnippet == null;
    if (hasMedia && plain) {
      final outgoing = m.direction == ChatMessageDirection.outgoing;
      return outgoing
          ? const EdgeInsets.fromLTRB(1, 1, 1, 5)
          : const EdgeInsets.fromLTRB(2, 2, 2, 6);
    }
    if (hasMedia && m.text.trim().isNotEmpty) {
      return const EdgeInsets.fromLTRB(10, 8, 10, 7);
    }
    return const EdgeInsets.fromLTRB(11, 9, 11, 8);
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.direction == ChatMessageDirection.outgoing;
    final isSystem = message.messageType == 'system';

    final Color fill;
    final Color bodyColor;
    final Color metaColor;

    if (isSystem) {
      fill = ChatConversationStyles.bubbleSystemFill;
      bodyColor = ChatConversationStyles.bubbleSystemText;
      metaColor = ChatConversationStyles.bubbleIncomingMeta;
    } else if (isOutgoing) {
      fill = ChatConversationStyles.bubbleOutgoingFill;
      bodyColor = ChatConversationStyles.bubbleOutgoingText;
      metaColor = ChatConversationStyles.bubbleOutgoingMeta;
    } else {
      fill = ChatConversationStyles.bubbleIncomingFill;
      bodyColor = AppColors.textBrand;
      metaColor = ChatConversationStyles.bubbleIncomingMeta;
    }

    final dividerColor = isOutgoing
        ? const Color(0x14000000)
        : Colors.white.withValues(alpha: 0.1);

    final imageItems =
        message.media.where((ChatMessageMediaItem m) => m.isImage).toList();
    final videoItems =
        message.media.where((ChatMessageMediaItem m) => m.isVideo).toList();
    final textOnly = message.text.trim().isEmpty;

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
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final maxBubble = constraints.maxWidth;
              final mediaW = math.min(248.0, maxBubble);

              final outgoingSingleImageOverlay = isOutgoing &&
                  imageItems.length == 1 &&
                  videoItems.isEmpty &&
                  textOnly &&
                  message.forwardedSnippet == null &&
                  (imageItems.first.url).trim().isNotEmpty;

              Widget buildImageTile(String url) {
                final img = CustomNetworkImage(
                  imageUrl: url,
                  height: 220,
                  fit: BoxFit.contain,
                );
                final framed = isOutgoing
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: img,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: img,
                      );
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: mediaW),
                  child: framed,
                );
              }

              Widget buildMetaRow({
                Color? timeColor,
                Color? receiptColor,
              }) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.timeLabel,
                      style: TextStyles.bodyMain.copyWith(
                        color: timeColor ?? metaColor,
                      ),
                    ),
                    if (isOutgoing &&
                        message.outgoingReceipt !=
                            ChatOutgoingReceipt.none) ...[
                      const Gap(4),
                      _OutgoingReadReceipts(
                        read: message.outgoingReceipt ==
                            ChatOutgoingReceipt.read,
                        iconColor: receiptColor,
                      ),
                    ],
                  ],
                );
              }

              final imageSection = <Widget>[];
              for (final item in imageItems) {
                if (item.url.trim().isEmpty) {
                  continue;
                }
                final tile = buildImageTile(item.url);
                if (outgoingSingleImageOverlay) {
                  imageSection.add(
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        tile,
                        Positioned(
                          right: 5,
                          bottom: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: buildMetaRow(
                                timeColor: Colors.white.withValues(alpha: 0.92),
                                receiptColor:
                                    Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  imageSection.add(tile);
                  imageSection.add(const Gap(5));
                }
              }

              final showBottomMeta =
                  !(outgoingSingleImageOverlay && imageItems.isNotEmpty);

              final content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message.forwardedSnippet != null) ...[
                    Text(
                      'Forwarded from',
                      style: TextStyles.bodyMain.copyWith(
                        color: metaColor.withValues(alpha: 0.95),
                      ),
                    ),
                    const Gap(6),
                    SizedBox(
                      width: mediaW,
                      child: Row(
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
                                color: bodyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(10),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: dividerColor,
                    ),
                    const Gap(10),
                  ],
                  ...imageSection,
                  for (final item in videoItems) ...[
                    Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        onTap: () => _openUrl(context, item.url),
                        borderRadius: BorderRadius.circular(4),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: mediaW),
                          child: SizedBox(
                            height: 160,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if ((item.thumbnailUrl ?? '').trim().isNotEmpty)
                                  CustomNetworkImage(
                                    imageUrl: item.thumbnailUrl!.trim(),
                                    fit: BoxFit.contain,
                                  )
                                else
                                  const ColoredBox(color: Color(0xFF1A1A1E)),
                                Center(
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    size: 44,
                                    color:
                                        Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Gap(5),
                  ],
                  if (message.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        message.text,
                        style: TextStyles.bodyLarge.copyWith(
                          color: bodyColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (showBottomMeta) ...[
                    const Gap(5),
                    buildMetaRow(),
                  ],
                ],
              );

              final wrapped = ClipPath(
                clipper: ChatBubbleClipper(outgoing: isOutgoing),
                child: ColoredBox(
                  color: fill,
                  child: Padding(
                    padding: _bubblePadding(message),
                    child: IntrinsicWidth(child: content),
                  ),
                ),
              );

              return Align(
                alignment:
                    isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubble),
                  child: GestureDetector(
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: wrapped,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Нижний отступ ленты при [ChatScaffold.overlayBottomNavigationBar]: пузыри
/// прокручиваются под полупрозрачный композер и остаются читаемыми.
double chatThreadComposerStackBottomPadding(
  BuildContext context, {
  required bool hasPendingAttachment,
  bool hasReplyDraft = false,
}) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  const composerVertical = 8.0 + 44.0 + 10.0;
  const pendingVertical = 8.0 + 72.0 + 6.0;
  const replyStrip = 56.0;
  const breathing = 24.0;
  return breathing +
      safeBottom +
      composerVertical +
      (hasPendingAttachment ? pendingVertical : 0) +
      (hasReplyDraft ? replyStrip : 0);
}

class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    required this.controller,
    required this.onSend,
    super.key,
    this.onAttachmentTap,
    this.onMicrophoneTap,
    this.hintText = 'Message',
    this.sendEnabled = true,
    this.hasPendingAttachment = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onMicrophoneTap;
  final String hintText;
  final bool sendEnabled;
  final bool hasPendingAttachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ChatComposerActionButton(
              icon: Icons.attach_file_rounded,
              onTap: onAttachmentTap,
            ),
            const Gap(10),
            Expanded(
              child: CustomTextField(
                controller: controller,
                labelText: hintText,
                hintText: hintText,
                showLabel: false,
                height: 44,
                borderRadius: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.022),
                customBorder: Border.all(
                  color: Colors.white.withValues(alpha: 0.055),
                  width: 1.25,
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
                final canSend =
                    sendEnabled && (hasText || hasPendingAttachment);
                return _ChatComposerActionButton(
                  icon: hasText || hasPendingAttachment
                      ? Icons.send_rounded
                      : Icons.mic_none_rounded,
                  onTap: canSend ? onSend : onMicrophoneTap,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.022),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.055),
              width: 1.25,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.textBrand.withValues(
              alpha: onTap == null ? 0.28 : 0.9,
            ),
            size: 22,
          ),
        ),
      ),
    );
  }
}
