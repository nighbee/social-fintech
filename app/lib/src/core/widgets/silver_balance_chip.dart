import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/api/client/dio/rest_client.dart';
import 'package:app/src/core/api/client/endpoints.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SilverBalanceChip extends StatefulWidget {
  const SilverBalanceChip({
    required this.count,
    super.key,
  })  : useLiveBalance = false,
        initialCount = 0,
        compact = false;

  const SilverBalanceChip.live({
    super.key,
    this.initialCount = 0,
    this.compact = false,
  })  : count = null,
        useLiveBalance = true;

  final int? count;
  final bool useLiveBalance;
  final int initialCount;
  final bool compact;

  @override
  State<SilverBalanceChip> createState() => _SilverBalanceChipState();
}

class _SilverBalanceChipState extends State<SilverBalanceChip> {
  late int _count;
  bool _livePending = false;
  bool _liveFailed = false;
  RestClient? _restClient;

  @override
  void initState() {
    super.initState();
    _count = widget.count ?? widget.initialCount;
    if (widget.useLiveBalance) {
      _livePending = true;
      _restClient = getIt<RestClient>(instanceName: 'DioClient');
      _loadLiveBalance();
    }
  }

  String get _displayText {
    if (widget.useLiveBalance) {
      if (_livePending || _liveFailed) {
        return '—';
      }
    }
    return _count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final iconSize = compact ? 16.0 : 24.0;
    final fontSize = compact ? 14.0 : 16.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.colorff3F3F40, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.icons.silverCoin.svg(width: iconSize, height: iconSize),
          Gap(compact ? 3 : 4),
          Text(
            _displayText,
            style: TextStyles.titleTag.copyWith(
              color: AppColors.colorffE5E5E5,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLiveBalance() async {
    final client = _restClient;
    if (client == null) {
      if (mounted) {
        setState(() {
          _livePending = false;
          _liveFailed = true;
        });
      }
      return;
    }
    final response = await client.get(EndPoints.economyBalance);
    response.fold(
      (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _livePending = false;
          _liveFailed = true;
        });
      },
      (result) {
        final raw = result.data;
        if (raw is! Map) {
          if (!mounted) {
            return;
          }
          setState(() {
            _livePending = false;
            _liveFailed = true;
          });
          return;
        }
        final data = Map<String, dynamic>.from(raw);
        final value = data['silver_balance'];
        final silverBalance = value is num ? value.toDouble() : null;
        if (!mounted) {
          return;
        }
        if (silverBalance == null) {
          setState(() {
            _livePending = false;
            _liveFailed = true;
          });
          return;
        }
        setState(() {
          _livePending = false;
          _liveFailed = false;
          _count = silverBalance.floor();
        });
      },
    );
  }
}
