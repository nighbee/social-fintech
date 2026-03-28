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
        initialCount = 0;

  const SilverBalanceChip.live({
    super.key,
    this.initialCount = 0,
  })  : count = null,
        useLiveBalance = true;

  final int? count;
  final bool useLiveBalance;
  final int initialCount;

  @override
  State<SilverBalanceChip> createState() => _SilverBalanceChipState();
}

class _SilverBalanceChipState extends State<SilverBalanceChip> {
  late int _count;
  RestClient? _restClient;

  @override
  void initState() {
    super.initState();
    _count = widget.count ?? widget.initialCount;
    if (widget.useLiveBalance) {
      _restClient = getIt<RestClient>(instanceName: 'DioClient');
      _loadLiveBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.colorff3F3F40, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.icons.silverCoin.svg(width: 24, height: 24),
          const Gap(4),
          Text(
            _count.toString(),
            style: TextStyles.titleTag.copyWith(
              color: AppColors.colorffE5E5E5,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLiveBalance() async {
    final client = _restClient;
    if (client == null) {
      return;
    }
    final response = await client.get(EndPoints.economyBalance);
    response.fold((_) {}, (result) {
      final raw = result.data;
      if (raw is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(raw);
      final value = data['silver_balance'];
      final silverBalance = value is num ? value.toDouble() : null;
      if (silverBalance == null || !mounted) {
        return;
      }
      setState(() {
        _count = silverBalance.floor();
      });
    });
  }
}
