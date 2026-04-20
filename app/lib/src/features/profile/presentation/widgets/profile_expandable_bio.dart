import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/presentation/widgets/profile_bio_glass_dialog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';


class ProfileExpandableBio extends StatefulWidget {
  const ProfileExpandableBio({
    required this.text,
    this.maxLines = 2,
    super.key,
  });

  final String text;
  final int maxLines;

  @override
  State<ProfileExpandableBio> createState() => _ProfileExpandableBioState();
}

class _ProfileExpandableBioState extends State<ProfileExpandableBio> {
  late final TapGestureRecognizer _moreTap;

  @override
  void initState() {
    super.initState();
    _moreTap = TapGestureRecognizer();
  }

  @override
  void dispose() {
    _moreTap.dispose();
    super.dispose();
  }

  TextPainter _paint(
    InlineSpan span,
    double maxWidth,
    BuildContext context,
    TextAlign textAlign,
  ) {
    return TextPainter(
      text: span,
      textDirection: Directionality.of(context),
      textAlign: textAlign,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: maxWidth);
  }

  int _lines(TextPainter tp) => tp.computeLineMetrics().length;

  String _insertWordBreakHints(String input) {
    const chunk = 10;
    final tokens = input.split(RegExp(r'(\s+)'));
    return tokens.map((token) {
      if (token.trim().isEmpty || token.length <= 16) return token;
      final buffer = StringBuffer();
      for (var i = 0; i < token.length; i++) {
        buffer.write(token[i]);
        if ((i + 1) % chunk == 0 && i + 1 != token.length) {
          buffer.write('\u200B');
        }
      }
      return buffer.toString();
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final normalizedText = _insertWordBreakHints(trimmed);

    _moreTap.onTap = () => showProfileBioGlassDialog(context, bio: trimmed);

    final baseStyle = DefaultTextStyle.of(context).style.merge(
      TextStyles.bodyMain.copyWith(
        fontFamily: 'Lora',
        fontWeight: FontWeight.w400,
        fontSize: 12,
        height: 16 / 12,
        color: const Color(0xFF838383),
      ),
    );
    final moreStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF838383),
    );
    const textAlign = TextAlign.start;
    const suffixSpanText = '\u2060...more';

    TextSpan spanWithMore(String prefix) {
      return TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: suffixSpanText,
            style: moreStyle,
            recognizer: _moreTap,
          ),
        ],
      );
    }

    Widget rich(InlineSpan span, {int? maxLines}) {
      return RichText(
        text: span,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow:
            maxLines != null ? TextOverflow.clip : TextOverflow.visible,
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        textDirection: Directionality.of(context),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return const SizedBox.shrink();
        }

        final fullSpan = TextSpan(text: normalizedText, style: baseStyle);
        if (_lines(_paint(fullSpan, maxW, context, textAlign)) <=
            widget.maxLines) {
          return SizedBox(
            width: maxW,
            child: rich(fullSpan, maxLines: null),
          );
        }

        var bestPrefix = '';
        for (var len = normalizedText.length; len >= 0; len--) {
          var prefix = normalizedText.substring(0, len);
          while (prefix.isNotEmpty && prefix.endsWith(' ')) {
            prefix = prefix.substring(0, prefix.length - 1);
          }
          if (_lines(
                _paint(
                  spanWithMore(prefix),
                  maxW,
                  context,
                  textAlign,
                ),
              ) <=
              widget.maxLines) {
            bestPrefix = prefix;
            break;
          }
        }

        return SizedBox(
          width: maxW,
          child: rich(
            spanWithMore(bestPrefix),
            maxLines: widget.maxLines,
          ),
        );
      },
    );
  }
}
