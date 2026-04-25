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

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(32, 32, 32, 0.50),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(74, 74, 74, 0.50),
                  blurRadius: 4,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onToggleExpanded,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: isExpanded
                        ? const EdgeInsets.fromLTRB(12, 16, 12, 0)
                        : const EdgeInsets.all(16),
                    child: isExpanded
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF303237),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatar.isNotEmpty
                                      ? Image.network(
                                          avatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyles.bodyLarge.copyWith(
                                        color: const Color(0xFFCACACA),
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
                                      ),
                                    ),
                                    const Gap(10),
                                    _ExpandablePanelDescription(
                                      text: task.description.isEmpty
                                          ? 'No description provided.'
                                          : task.description,
                                      textStyle: TextStyles.bodyMain.copyWith(
                                        fontFamily: FontFamily.lora,
                                        color: const Color(0xFFCACACA),
                                        fontSize: 16,
                                        height: 20 / 16,
                                      ),
                                      linkStyle: TextStyles.bodyMain.copyWith(
                                        fontFamily: FontFamily.lora,
                                        color: const Color(0xFFDDDDDD),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 16 / 12,
                                      ),
                                      inlineOverflowAction: true,
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              SizedBox(
                                width: 58,
                                height: 20,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Text(
                                    'Code:$code',
                                    style: TextStyles.bodyMain.copyWith(
                                      fontFamily: FontFamily.lora,
                                      color: const Color(0xFF9A9A9A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      height: 20 / 12,
                                      letterSpacing: -0.24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyles.bodyLarge.copyWith(
                                        color: const Color(0xFFCACACA),
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      'Code:$code',
                                      style: TextStyles.bodyMain.copyWith(
                                        color: const Color(0xFF9B9B9B),
                                        fontSize: 16,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, right: 14),
                                child: SizedBox(
                                  width: 94,
                                  height: 16,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'view my request',
                                        maxLines: 1,
                                        style: TextStyles.bodyMain.copyWith(
                                          fontFamily: FontFamily.lora,
                                          color: const Color(0xFFDDDDDD),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 16 / 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      avatar.isNotEmpty ? 70 : 12,
                      10,
                      avatar.isNotEmpty ? 58 : 12,
                      0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Required:',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFF9A9A9A),
                                fontFamily: FontFamily.lora,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                letterSpacing: -0.24,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${task.workersNeeded} heroes',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFFF2F2F2),
                                fontFamily: FontFamily.lora,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                letterSpacing: -0.24,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Image.asset(
                              'assets/images/Heroes.png',
                              width: 14,
                              height: 14,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Reward:',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFF9A9A9A),
                                fontFamily: FontFamily.lora,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                letterSpacing: -0.24,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.reward.toStringAsFixed(0),
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFFF2F2F2),
                                fontFamily: FontFamily.lora,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 20 / 14,
                                letterSpacing: -0.24,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Assets.icons.silverCoin.svg(width: 20, height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (isExpanded) const SizedBox(height: 10),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: InkWell(
                        onTap: onCancel,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.transparent,
                            border: Border.all(
                              color: const Color(0xFFD93337),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Cancel my request',
                            style: TextStyles.bodyMain.copyWith(
                              fontFamily: FontFamily.lora,
                              fontSize: 12,
                              height: 16 / 12,
                              color: const Color(0xFFD93337),
                              fontWeight: FontWeight.w600,
                            ),
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
    final normalizedTitle =
        task.title.trim().isEmpty ? 'Help request' : task.title.trim();
    final hasDescription = task.description.trim().isNotEmpty;
    final description = hasDescription
        ? task.description
        : 'No description provided for this request.';

    bool containsAny(String value, List<String> tokens) {
      for (final token in tokens) {
        if (value.contains(token)) {
          return true;
        }
      }
      return false;
    }

    final normalizedTaskStatus = task.status.trim().toLowerCase();
    final normalizedApplicationStatus = task.applicationStatus.trim().toLowerCase();
    final isTaskClosed = containsAny(
      normalizedTaskStatus,
      <String>['cancelled', 'canceled', 'completed', 'closed'],
    );
    final isTaskAlreadyAssigned = containsAny(
      normalizedTaskStatus,
      <String>[
        'accepted',
        'assigned',
        'arrived',
        'in_progress',
        'code_required',
        'code_verified',
        'confirmed',
      ],
    );
    final isAlreadyRejected = containsAny(
      normalizedApplicationStatus,
      <String>['rejected', 'declined', 'withdrawn'],
    );
    final isApplicationAlreadyAssigned = containsAny(
      normalizedApplicationStatus,
      <String>[
        'accepted',
        'assigned',
        'arrived',
        'in_progress',
        'code_required',
        'code_verified',
        'confirmed',
      ],
    );
    final isTaskFull =
        task.workersNeeded > 0 && task.workersFilled >= task.workersNeeded;
    final canApply = !(isTaskClosed ||
        isTaskAlreadyAssigned ||
        isAlreadyRejected ||
        isApplicationAlreadyAssigned ||
        isTaskFull);

    const cardHPadding = 16.0;
    const avatarGap = 12.0;

    final metricsTextStyle = TextStyles.bodyMain.copyWith(
      color: const Color(0xFFCACACA),
      fontFamily: FontFamily.lora,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: -0.24,
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(32, 32, 32, 0.50),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(74, 74, 74, 0.50),
                      blurRadius: 4,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        cardHPadding,
                        16,
                        cardHPadding,
                        0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TaskAvatar(
                            seedText: task.creatorUsername.trim().isNotEmpty
                                ? task.creatorUsername
                                : normalizedTitle,
                            username: task.creatorUsername,
                            avatarUrl: task.creatorAvatarUrl,
                            size: 46,
                            borderColor: Colors.white,
                            borderWidth: 1,
                          ),
                          const Gap(avatarGap),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  normalizedTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyles.bodyMain.copyWith(
                                    fontFamily: FontFamily.lora,
                                    color: const Color(0xFFF2F2F2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 20 / 16,
                                    letterSpacing: -0.25,
                                  ),
                                ),
                                const Gap(10),
                                _ExpandablePanelDescription(
                                  text: description,
                                  collapsedMaxLines: 6,
                                  textStyle: TextStyles.bodyMain.copyWith(
                                    fontFamily: FontFamily.lora,
                                    color: const Color(0xFFCACACA),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 20 / 14,
                                    letterSpacing: -0.25,
                                  ),
                                  linkStyle: TextStyles.bodyMain.copyWith(
                                    fontFamily: FontFamily.lora,
                                    color: const Color(0xFFDDDDDD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 16 / 12,
                                  ),
                                  inlineOverflowAction: true,
                                ),
                                const Gap(10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Required:',
                                          style: metricsTextStyle,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${task.workersNeeded} heroes',
                                          style: metricsTextStyle,
                                        ),
                                        const SizedBox(width: 6),
                                        Image.asset(
                                          'assets/images/Heroes.png',
                                          width: 14,
                                          height: 14,
                                          fit: BoxFit.contain,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 20),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Reward:',
                                          style: metricsTextStyle,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          task.reward.toStringAsFixed(0),
                                          style: metricsTextStyle,
                                        ),
                                        const SizedBox(width: 6),
                                        Assets.icons.silverCoin
                                            .svg(width: 20, height: 20),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        cardHPadding,
                        0,
                        cardHPadding,
                        20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: InkWell(
                          onTap: canApply ? () => onApply(task.id) : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: canApply
                                  ? const Color(0xFFE5E5E5)
                                  : const Color(0xFF7A7A7A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              canApply ? 'I can help' : 'Unavailable',
                              style: TextStyles.bodyMain.copyWith(
                                fontSize: 12,
                                height: 16 / 12,
                                color: canApply ? Colors.black87 : Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
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
    this.textStyle,
    this.linkStyle,
    this.inlineOverflowAction = false,
  });

  final String text;
  final int collapsedMaxLines;
  final TextStyle? textStyle;
  final TextStyle? linkStyle;
  final bool inlineOverflowAction;

  @override
  State<_ExpandablePanelDescription> createState() =>
      _ExpandablePanelDescriptionState();
}

class _ExpandablePanelDescriptionState
    extends State<_ExpandablePanelDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        TextStyles.bodyMain.copyWith(
          color: Colors.white70,
          height: 1.35,
        );
    final linkStyle = widget.linkStyle ??
        TextStyles.bodyMain.copyWith(
          color: const Color(0xFFC9D7F2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
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

        final showInlineMore =
            widget.inlineOverflowAction && !_expanded && isOverflowing;

        String buildInlineCollapsedText() {
          final suffix = ' More';
          var low = 0;
          var high = widget.text.length;
          var best = '';
          while (low <= high) {
            final mid = (low + high) ~/ 2;
            final candidateText =
                '${widget.text.substring(0, mid).trimRight()}...$suffix';
            final candidatePainter = TextPainter(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: '${widget.text.substring(0, mid).trimRight()}...'),
                  TextSpan(text: suffix, style: linkStyle),
                ],
                style: style,
              ),
              textDirection: Directionality.of(context),
              maxLines: widget.collapsedMaxLines,
            )..layout(maxWidth: constraints.maxWidth);
            if (!candidatePainter.didExceedMaxLines) {
              best = candidateText;
              low = mid + 1;
            } else {
              high = mid - 1;
            }
          }
          return best.isEmpty ? widget.text : best;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showInlineMore)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: buildInlineCollapsedText()
                            .replaceFirst(RegExp(r'\sMore$'), ''),
                        style: style,
                      ),
                      TextSpan(text: ' More', style: linkStyle),
                    ],
                  ),
                  maxLines: widget.collapsedMaxLines,
                  overflow: TextOverflow.clip,
                ),
              )
            else
              Text(
                widget.text,
                maxLines: _expanded ? null : widget.collapsedMaxLines,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: style,
              ),
            if (isOverflowing && !showInlineMore)
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _expanded ? 'Hide' : 'More',
                      style: linkStyle,
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
    this.username = '',
    this.avatarUrl = '',
    this.size = 40,
    this.borderColor,
    this.borderWidth,
  });

  final String seedText;
  final String username;
  final String avatarUrl;
  final double size;
  final Color? borderColor;
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final trimmed = seedText.trim();
    final first = trimmed.isEmpty ? '' : trimmed.substring(0, 1).toUpperCase();
    final hasLetter = RegExp(r'[A-ZА-Я0-9]').hasMatch(first);
    return FutureBuilder<String>(
      future: MapAvatarResolverService.instance.resolveAvatar(
        fallbackUrl: avatarUrl,
        username: username,
      ),
      builder: (context, snapshot) {
        final normalizedAvatarUrl = snapshot.data?.trim() ?? '';
        final hasAvatar = normalizedAvatarUrl.isNotEmpty;

        final resolvedBorderColor =
            borderColor ?? Colors.white.withValues(alpha: 0.28);
        final resolvedBorderWidth = borderWidth ?? 0.5;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A5D64), Color(0xFF35383E)],
            ),
            border: Border.all(
              color: resolvedBorderColor,
              width: resolvedBorderWidth,
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
                          : Icon(
                              Icons.person,
                              color: Colors.white,
                              size: size * 0.45,
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
                        : Icon(
                            Icons.person,
                            color: Colors.white,
                            size: size * 0.45,
                          ),
                  ),
          ),
        );
      },
    );
  }
}
