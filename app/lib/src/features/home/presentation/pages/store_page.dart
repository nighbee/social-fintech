import 'dart:async';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_outlined_button.dart';
import 'package:app/src/core/widgets/glass_container.dart';
import 'package:app/src/features/home/domain/entities/store_summary_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  _StorePageState();

  final HomeBloc _bloc = getIt<HomeBloc>();
  final IProfileRepository _profileRepository =
      getIt<IProfileRepository>(instanceName: 'ProfileRepositoryImpl');
  final _RevenueCatStoreService _revenueCatStore = _RevenueCatStoreService();
  Timer? _countdownTimer;
  bool _isStoreSummaryLoading = false;
  bool _isProductsLoading = false;
  bool _isPurchasing = false;
  String? _storeLoadError;
  String? _productsLoadError;
  String? _activePurchaseProductId;
  Map<String, Package> _packagesByProductId = const {};

  static const List<_StoreOffer> _offers = [
    _StoreOffer(
      title: 'Starter',
      productId: 'starter_pack',
      amount: 3,
      priceLabel: 'KZT 5 990.00',
      description: 'Make your mark. Recognize actions that deserve to be seen.',
      isFeaturedTitle: true,
    ),
    _StoreOffer(
      title: 'Supporter',
      productId: 'supporter_pack',
      amount: 10,
      priceLabel: 'KZT 5 990.00',
      description: 'Support with intention. Reward those who truly stand out.',
    ),
    _StoreOffer(
      title: 'Sponsor',
      productId: 'sponsor_pack',
      amount: 30,
      priceLabel: 'KZT 5 990.00',
      description: 'Amplify impact. Your recognition carries weight.',
    ),
    _StoreOffer(
      title: 'Patron',
      productId: 'patron_pack',
      amount: 120,
      priceLabel: 'KZT 5 990.00',
      description:
          'The Patron Badge marks those who sustain a culture where Honor is earned and openly recognized.',
      badgeLabel: '+  Patron Badge',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshStoreSummary();
    _loadRevenueCatProducts();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  bool _isStoreSummaryLoaded(StoreSummaryEntity summary) {
    return summary.limits.nextReset.isNotEmpty;
  }

  Future<void> _refreshStoreSummary() async {
    setState(() {
      _isStoreSummaryLoading = true;
      _storeLoadError = null;
    });

    final result = await _bloc.getStoreSummaryDirect();
    result.fold(
      (error) {
        if (!mounted) return;
        setState(() {
          _storeLoadError = error.message;
          _isStoreSummaryLoading = false;
        });
      },
      (_) {
        if (!mounted) return;
        setState(() {
          _storeLoadError = null;
          _isStoreSummaryLoading = false;
        });
      },
    );
  }

  Future<String> _resolveCurrentUserId() async {
    final result = await _profileRepository.getCurrentUser();
    return result.match(
      (error) => throw Exception(error.message),
      (profile) {
        final userId = profile.userId.trim();
        if (userId.isEmpty) {
          throw Exception('User profile is not ready yet.');
        }
        return userId;
      },
    );
  }

  Future<void> _loadRevenueCatProducts() async {
    if (!_revenueCatStore.hasApiKey) {
      setState(() {
        _productsLoadError =
            'RevenueCat key is missing. Add it before Play testing.';
      });
      return;
    }

    setState(() {
      _isProductsLoading = true;
      _productsLoadError = null;
    });

    try {
      final userId = await _resolveCurrentUserId();
      final packages = await _revenueCatStore.loadPackages(userId);
      if (!mounted) return;
      setState(() {
        _packagesByProductId = {
          for (final package in packages)
            package.storeProduct.identifier: package,
        };
        _productsLoadError = _packagesByProductId.isEmpty
            ? 'No RevenueCat products found for this build.'
            : null;
        _isProductsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsLoadError = _formatStoreError(e);
        _isProductsLoading = false;
      });
    }
  }

  Future<void> _purchaseOffer(_StoreOffer offer) async {
    if (_isPurchasing) return;

    if (!_revenueCatStore.hasApiKey) {
      await _showStoreMessageDialog(
        context,
        title: 'Payments unavailable',
        message:
            'RevenueCat is not configured in this build yet. Add the API key and upload a new testing build.',
        buttonLabel: 'Ok',
        messageColor: const Color(0xFFA3A3A3),
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.10),
        borderColor: Colors.white.withValues(alpha: 0.08),
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
      );
      return;
    }

    var package = _packagesByProductId[offer.productId];
    if (package == null) {
      await _loadRevenueCatProducts();
      if (!mounted) return;
      package = _packagesByProductId[offer.productId];
    }

    if (package == null) {
      await _showStoreMessageDialog(
        context,
        title: 'Product unavailable',
        message:
            'This silver pack is not available from RevenueCat yet. Check the product id in Google Play and RevenueCat.',
        buttonLabel: 'Ok',
        messageColor: const Color(0xFFA3A3A3),
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.10),
        borderColor: Colors.white.withValues(alpha: 0.08),
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
      _activePurchaseProductId = offer.productId;
    });

    try {
      final userId = await _resolveCurrentUserId();
      final completed = await _revenueCatStore.purchasePackage(
        userId: userId,
        package: package,
      );
      if (!mounted) return;
      setState(() {
        _isPurchasing = false;
        _activePurchaseProductId = null;
      });
      if (!completed) return;

      await _refreshStoreSummary();
      if (!mounted) return;
      await _showStoreMessageDialog(
        context,
        title: 'Purchase complete',
        message:
            'Your Silver Honors purchase was completed. Balance will refresh after the server confirms the RevenueCat webhook.',
        buttonLabel: 'Ok',
        messageColor: const Color(0xFFA3A3A3),
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.10),
        borderColor: Colors.white.withValues(alpha: 0.08),
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPurchasing = false;
        _activePurchaseProductId = null;
      });
      await _showStoreMessageDialog(
        context,
        title: 'Purchase failed',
        message: _formatStoreError(e),
        buttonLabel: 'Ok',
        messageColor: const Color(0xFFA3A3A3),
        backgroundColor: AppColors.colorff202020.withValues(alpha: 0.10),
        borderColor: Colors.white.withValues(alpha: 0.08),
        dropShadowColor: Colors.black.withValues(alpha: 0.48),
        dropShadowBlurRadius: 32,
        dropShadowOffset: const Offset(0, 4),
      );
    }
  }

  String _formatStoreError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Store is unavailable right now.' : message;
  }

  String _buildNextFreeMessage(DateTime? nextAccrualDateTime) {
    if (nextAccrualDateTime == null) {
      return 'Available now';
    }

    final remaining = nextAccrualDateTime.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return 'Available now';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    if (hours > 0) {
      return 'Next free in ${hours}h ${minutes <= 0 ? 1 : minutes}m';
    }

    final safeMinutes = remaining.inMinutes <= 0 ? 1 : remaining.inMinutes;
    return 'Next free in ${safeMinutes}m';
  }

  _StoreStatusData _resolveStatusData(StoreSummaryEntity summary) {
    if (!_isStoreSummaryLoaded(summary)) {
      return _StoreStatusData.loading(
        message: _isStoreSummaryLoading ? 'Loading...' : 'Unavailable',
      );
    }

    switch (summary.status) {
      case StoreSummaryStatus.nextFree:
        return _StoreStatusData(
          silverHonors: summary.silverHonorsCount,
          message: _buildNextFreeMessage(summary.nextAccrualDateTime),
          tone: _StoreStatusTone.neutral,
          sectionGap: 40,
        );
      case StoreSummaryStatus.storageFull:
        return _StoreStatusData(
          silverHonors: summary.silverHonorsCount,
          message: 'Storage full',
          tone: _StoreStatusTone.warning,
          sectionGap: 30,
        );
      case StoreSummaryStatus.freeLimitReached:
        return _StoreStatusData(
          silverHonors: summary.silverHonorsCount,
          message: 'Free limit reached',
          tone: _StoreStatusTone.warning,
          sectionGap: 30,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      bloc: _bloc,
      builder: (context, state) {
        final viewModel = state.maybeWhen(
          loading: (viewModel) => viewModel,
          loaded: (viewModel) => viewModel,
          orElse: HomeViewModel.new,
        );
        final statusData = _resolveStatusData(viewModel.storeSummary);

        return Scaffold(
          backgroundColor: AppColors.colorff19191A,
          appBar: CustomAppBar(
            title: 'Store',
            backgroundColor: AppColors.colorff19191A,
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _StoreStatusCard(
                    status: statusData,
                    onTap: () => _showStoreMessageDialog(
                      context,
                      title: 'Silver Honor',
                      message:
                          'Honors are rare and valuable. To keep the system fair, repeated honors to the same user are limited. Any attempts to manipulate stats will result in a reset.',
                      buttonLabel: 'Ok',
                      messageColor: const Color(0xFFA3A3A3),
                      backgroundColor: AppColors.colorff202020.withValues(
                        alpha: 0.10,
                      ),
                      borderColor: Colors.white.withValues(alpha: 0.08),
                      dropShadowColor: Colors.black.withValues(alpha: 0.48),
                      dropShadowBlurRadius: 32,
                      dropShadowOffset: const Offset(0, 4),
                    ),
                  ),
                  if (_storeLoadError != null) ...[
                    const Gap(12),
                    Text(
                      _storeLoadError!,
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.colorffEF4444,
                      ),
                    ),
                  ],
                  Gap(statusData.sectionGap),
                  if (_productsLoadError != null) ...[
                    Text(
                      _productsLoadError!,
                      textAlign: TextAlign.center,
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 13,
                        height: 1.4,
                        color: const Color(0xFFA3A3A3),
                      ),
                    ),
                    const Gap(16),
                  ],
                  for (var index = 0; index < _offers.length; index++) ...[
                    Builder(
                      builder: (context) {
                        final offer = _offers[index];
                        final package = _packagesByProductId[offer.productId];
                        final isLoading =
                            _activePurchaseProductId == offer.productId ||
                                (_isProductsLoading && package == null);
                        final offerWithLivePrice = offer.copyWith(
                          priceLabel: package?.storeProduct.priceString ??
                              offer.priceLabel,
                        );

                        return _StoreOfferCard(
                          offer: offerWithLivePrice,
                          isLoading: isLoading,
                          onTap: () => _purchaseOffer(offer),
                          onBadgeTap: () => _showStoreMessageDialog(
                            context,
                            title: 'Patron Status Unlocked',
                            message:
                                "You've secured 120 Silver Honors and earned the Patron Badge.\nYour recognition now carries lasting influence.",
                            buttonLabel: 'View profile',
                            messageColor: const Color(0xFFA3A3A3),
                            backgroundColor: AppColors.colorff202020.withValues(
                              alpha: 0.10,
                            ),
                            borderColor: Colors.white.withValues(alpha: 0.08),
                            dropShadowColor:
                                Colors.black.withValues(alpha: 0.48),
                            dropShadowBlurRadius: 32,
                            dropShadowOffset: const Offset(0, 4),
                            onConfirmed: () {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  context.push(RoutePaths.profile);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                    if (index != _offers.length - 1) const Gap(20),
                  ],
                  const Gap(28),
                  Text(
                    'Gold Honor cannot be purchased. It is earned only from other users.',
                    style: TextStyles.bodyMain.copyWith(
                      fontSize: 13,
                      height: 16 / 13,
                      color: AppColors.colorff838383,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStoreMessageDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonLabel,
    required Color messageColor,
    required Color backgroundColor,
    required Color borderColor,
    required Color dropShadowColor,
    required double dropShadowBlurRadius,
    required Offset dropShadowOffset,
    VoidCallback? onConfirmed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (_) => _StoreMessageDialog(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
        messageColor: messageColor,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        dropShadowColor: dropShadowColor,
        dropShadowBlurRadius: dropShadowBlurRadius,
        dropShadowOffset: dropShadowOffset,
        onConfirmed: onConfirmed,
      ),
    );
  }
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({
    required this.status,
    required this.onTap,
  });

  final _StoreStatusData status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 6,
        blurSigma: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        backgroundColor: Colors.black.withValues(alpha: 0.20),
        borderColor: Colors.white.withValues(alpha: 0.72),
        borderWidth: 1.2,
        enableWhiteGlow: false,
        enableDropShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Silver Honors: ${status.silverHonors}',
                  style: TextStyles.titleMain.copyWith(
                    color: AppColors.colorffffffff,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
            const Gap(8),
            switch (status.tone) {
              _StoreStatusTone.neutral => Text(
                  status.message,
                  style: TextStyles.bodyLarge.copyWith(
                    color: AppColors.colorff838383,
                  ),
                ),
              _StoreStatusTone.warning => _StoreWarningText(
                  message: status.message,
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _StoreWarningText extends StatelessWidget {
  const _StoreWarningText({required this.message});

  final String message;

  static const LinearGradient _warningGradient = LinearGradient(
    colors: [
      Color(0xFFCDAD00),
      Color(0xFF675700),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _warningGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        message,
        style: TextStyles.bodyLarge.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StoreMessageDialog extends StatelessWidget {
  const _StoreMessageDialog({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.messageColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.dropShadowColor,
    required this.dropShadowBlurRadius,
    required this.dropShadowOffset,
    this.onConfirmed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final Color messageColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color dropShadowColor;
  final double dropShadowBlurRadius;
  final Offset dropShadowOffset;
  final VoidCallback? onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: GlassContainer(
        borderRadius: 12,
        blurSigma: 18,
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderWidth: 1,
        enableWhiteGlow: false,
        dropShadowColor: dropShadowColor,
        dropShadowBlurRadius: dropShadowBlurRadius,
        dropShadowOffset: dropShadowOffset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textBrand,
              ),
            ),
            const Gap(12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyles.bodyLarge.copyWith(
                color: messageColor,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const Gap(20),
            CustomOutlinedButton(
              text: buttonLabel,
              onTap: () {
                Navigator.of(context).pop();
                onConfirmed?.call();
              },
              width: double.infinity,
              borderRadius: 6,
              borderColor: AppColors.textBrand,
              backgroundColor: Colors.transparent,
              textStyle: TextStyles.titleTag.copyWith(
                fontSize: 16,
                color: const Color(0xFFEAEAEA),
                fontWeight: FontWeight.w400,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreOfferCard extends StatelessWidget {
  const _StoreOfferCard({
    required this.offer,
    required this.isLoading,
    required this.onTap,
    this.onBadgeTap,
  });

  final _StoreOffer offer;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      borderRadius: 6,
      blurSigma: 16,
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.colorff202020.withValues(alpha: 0.12),
      borderColor: Colors.white.withValues(alpha: 0.04),
      borderWidth: 1,
      whiteGlowColor: Colors.white.withValues(alpha: 0.04),
      whiteGlowBlurRadius: 18,
      whiteGlowOffset: const Offset(0, -2),
      dropShadowColor: Colors.black.withValues(alpha: 0.18),
      dropShadowBlurRadius: 18,
      dropShadowOffset: const Offset(0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            style: TextStyles.titleBig.copyWith(
                              color: AppColors.textBrand,
                              fontWeight: offer.isFeaturedTitle
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              height: 1.2,
                              letterSpacing: -0.48,
                            ),
                          ),
                          const Gap(16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '${offer.amount}',
                                style: TextStyles.bodyLarge.copyWith(
                                  fontSize: 32,
                                  height: 1.2,
                                  color: AppColors.textBrand,
                                ),
                              ),
                              const Gap(6),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Assets.icons.silverCoin.svg(
                                  width: 26,
                                  height: 26,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    _PricePill(
                      label: offer.priceLabel,
                      isLoading: isLoading,
                    ),
                  ],
                ),
                const Gap(12),
                Text(
                  offer.description,
                  style: TextStyles.bodyMain.copyWith(
                    fontSize: 14,
                    height: 1.4,
                    color: const Color(0xFFA3A3A3),
                  ),
                ),
              ],
            ),
          ),
          if (offer.badgeLabel != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBadgeTap,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.colorff6D6D6Dop35,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      offer.badgeLabel!,
                      style: TextStyles.bodyLarge.copyWith(
                        fontSize: 16,
                        height: 1.4,
                        color: AppColors.colorffb39600,
                      ),
                    ),
                    const Gap(8),
                    Image.asset(
                      'assets/images/patronBadge.png',
                      width: 25,
                      height: 25,
                      filterQuality: FilterQuality.high,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({
    required this.label,
    required this.isLoading,
  });

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundBrandLight,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: isLoading
            ? SizedBox(
                key: const ValueKey('loader'),
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textNeutral,
                  ),
                ),
              )
            : Text(
                label,
                key: ValueKey(label),
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textNeutral,
                ),
              ),
      ),
    );
  }
}

class _StoreOffer {
  const _StoreOffer({
    required this.title,
    required this.productId,
    required this.amount,
    required this.priceLabel,
    required this.description,
    this.badgeLabel,
    this.isFeaturedTitle = false,
  });

  final String title;
  final String productId;
  final int amount;
  final String priceLabel;
  final String description;
  final String? badgeLabel;
  final bool isFeaturedTitle;

  _StoreOffer copyWith({
    String? priceLabel,
  }) {
    return _StoreOffer(
      title: title,
      productId: productId,
      amount: amount,
      priceLabel: priceLabel ?? this.priceLabel,
      description: description,
      badgeLabel: badgeLabel,
      isFeaturedTitle: isFeaturedTitle,
    );
  }
}

enum _StoreStatusTone {
  neutral,
  warning,
}

class _StoreStatusData {
  const _StoreStatusData({
    required this.silverHonors,
    required this.message,
    required this.tone,
    required this.sectionGap,
  });

  const _StoreStatusData.loading({
    this.message = 'Loading...',
  })  : silverHonors = 0,
        tone = _StoreStatusTone.neutral,
        sectionGap = 40;

  final int silverHonors;
  final String message;
  final _StoreStatusTone tone;
  final double sectionGap;
}

class _RevenueCatStoreService {
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: '',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: '',
  );

  bool _configured = false;
  String? _configuredUserId;

  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  String get _apiKey {
    if (kIsWeb) return '';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidApiKey,
      TargetPlatform.iOS => _iosApiKey,
      _ => '',
    };
  }

  Future<void> _configure(String userId) async {
    final apiKey = _apiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('RevenueCat API key is missing.');
    }

    if (!_configured) {
      await Purchases.setLogLevel(
          kReleaseMode ? LogLevel.warn : LogLevel.debug);
      final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
      await Purchases.configure(configuration);
      _configured = true;
      _configuredUserId = userId;
      return;
    }

    if (_configuredUserId != userId) {
      await Purchases.logIn(userId);
      _configuredUserId = userId;
    }
  }

  Future<List<Package>> loadPackages(String userId) async {
    await _configure(userId);
    final offerings = await Purchases.getOfferings();
    final currentPackages = offerings.current?.availablePackages;
    if (currentPackages != null && currentPackages.isNotEmpty) {
      return currentPackages;
    }

    final packagesById = <String, Package>{};
    for (final offering in offerings.all.values) {
      for (final package in offering.availablePackages) {
        packagesById[package.storeProduct.identifier] = package;
      }
    }
    return packagesById.values.toList(growable: false);
  }

  Future<bool> purchasePackage({
    required String userId,
    required Package package,
  }) async {
    await _configure(userId);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return true;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }
}
