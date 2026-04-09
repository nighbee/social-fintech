part of 'package:app/src/features/map/presentation/pages/map_page.dart';

class _MyRequestPanel extends StatelessWidget {
  const _MyRequestPanel({
    required this.task,
    required this.isExpanded,
    required this.avatarUrl,
    required this.onToggleExpanded,
    required this.onCancel,
  });

  final MapTaskEntity task;
  final bool isExpanded;
  final String? avatarUrl;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final code = _extractVerificationCode(task.status);
    final title = _truncateTitleForHeader(task.title);
    final avatar = avatarUrl?.trim() ?? '';
    final requiredText =
        'Required: ${task.workersNeeded} heroes  |  Reward: ${task.reward.toStringAsFixed(0)}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: MapUiPalette.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MapUiPalette.panelBorder),
            boxShadow: [
              BoxShadow(
                color: MapUiPalette.panelTopGlow,
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: MapUiPalette.panelDropShadow,
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3341),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: ClipOval(
                          child: avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.bodyLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Code:$code',
                              style: TextStyles.bodyMain.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExpandablePanelDescription(
                        text: task.description.isEmpty
                            ? 'No description provided.'
                            : task.description,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        requiredText,
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: InkWell(
                          onTap: onCancel,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xAAE14D4D),
                              ),
                            ),
                            child: Text(
                              'Cancel my request',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFFE26D6D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _extractVerificationCode(String status) {
    if (!status.startsWith('mine|')) {
      return '----';
    }
    final raw = status.substring(5).trim();
    final code = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (code.length >= 4) {
      return code.substring(0, 4);
    }
    if (code.isNotEmpty) {
      return code.padRight(4, '-');
    }
    return '----';
  }

  String _truncateTitleForHeader(String rawTitle) {
    final normalized = rawTitle.trim();
    if (normalized.isEmpty) {
      return 'Help request';
    }
    if (normalized.length <= 34) {
      return normalized;
    }
    return '${normalized.substring(0, 34)}...more';
  }
}

class _NearbyTasksPanel extends StatelessWidget {
  const _NearbyTasksPanel({
    required this.tasks,
    required this.onApply,
  });

  final List<MapTaskEntity> tasks;
  final ValueChanged<String> onApply;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final task = tasks.first;
    final normalizedTitle = task.title.trim().isEmpty
        ? 'Help request'
        : task.title.trim();
    final hasDescription = task.description.trim().isNotEmpty;
    final description = hasDescription
        ? task.description
        : 'No description provided for this request.';

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x33202020),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: MapUiPalette.panelBorder),
            boxShadow: [
              BoxShadow(
                color: MapUiPalette.panelTopGlow,
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
              BoxShadow(
                color: MapUiPalette.panelDropShadow,
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _TaskAvatar(
                      seedText: task.creatorUsername.trim().isNotEmpty
                          ? task.creatorUsername
                          : normalizedTitle,
                      avatarUrl: task.creatorAvatarUrl,
                    ),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        normalizedTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.titleMain.copyWith(
                          color: const Color(0xFFF2F2F2),
                          fontSize: 18,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ExpandablePanelDescription(
                  text: description,
                  collapsedMaxLines: 6,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Required: ${task.workersNeeded} heroes',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Assets.icons.silverCoin.svg(width: 18, height: 18),
                    const SizedBox(width: 4),
                    Text(
                      task.reward.toStringAsFixed(0),
                      style: TextStyles.bodyMain.copyWith(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    onTap: () => onApply(task.id),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'I can help',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

class _ExpandablePanelDescription extends StatefulWidget {
  const _ExpandablePanelDescription({
    required this.text,
    this.collapsedMaxLines = 4,
  });

  final String text;
  final int collapsedMaxLines;

  @override
  State<_ExpandablePanelDescription> createState() =>
      _ExpandablePanelDescriptionState();
}

class _ExpandablePanelDescriptionState extends State<_ExpandablePanelDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = TextStyles.bodyMain.copyWith(
      color: Colors.white70,
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.text, style: style);
        final painter = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: widget.collapsedMaxLines,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : widget.collapsedMaxLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: style,
            ),
            if (isOverflowing)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? 'Hide' : 'More',
                      style: TextStyles.bodyMain.copyWith(
                        color: const Color(0xFFC9D7F2),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskAvatar extends StatelessWidget {
  const _TaskAvatar({
    required this.seedText,
    this.avatarUrl = '',
  });

  final String seedText;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = seedText.trim();
    final first = trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
    final hasLetter = RegExp(r'[A-ZА-Я0-9]').hasMatch(first);
    final normalizedAvatarUrl = avatarUrl.trim();
    final hasAvatar = normalizedAvatarUrl.isNotEmpty;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5E7698), Color(0xFF2E3C52)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      child: ClipOval(
        child: hasAvatar
            ? Image.network(
                normalizedAvatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: hasLetter
                      ? Text(
                          first,
                          style: TextStyles.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              )
            : Center(
                child: hasLetter
                    ? Text(
                        first,
                        style: TextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
      ),
    );
  }
}
