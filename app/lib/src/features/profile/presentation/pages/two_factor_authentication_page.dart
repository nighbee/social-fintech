import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

const List<_TwoFactorMethodItem> _twoFactorMethods = <_TwoFactorMethodItem>[
  _TwoFactorMethodItem(
    id: 'phone',
    title: 'Phone',
    description: 'You\'ll receive a verification code via SMS.',
    icon: Icons.smartphone_outlined,
  ),
  _TwoFactorMethodItem(
    id: 'email',
    title: 'Email',
    description: 'You\'ll receive a verification code at\ne***8@gmail.com.',
    icon: Icons.mail_outline_rounded,
  ),
  _TwoFactorMethodItem(
    id: 'authenticator',
    title: 'Authenticator',
    description: 'Install an app to generate your verification code.',
    icon: Icons.shield_outlined,
  ),
  _TwoFactorMethodItem(
    id: 'password',
    title: 'Password',
    description: null,
    icon: Icons.password_rounded,
  ),
];

class TwoFactorAuthenticationPage extends StatefulWidget {
  const TwoFactorAuthenticationPage({
    super.key,
    required this.initialSelectedMethodIds,
  });

  final List<String> initialSelectedMethodIds;

  @override
  State<TwoFactorAuthenticationPage> createState() =>
      _TwoFactorAuthenticationPageState();
}

class _TwoFactorAuthenticationPageState
    extends State<TwoFactorAuthenticationPage> {
  late Set<String> _selectedMethodIds;

  @override
  void initState() {
    super.initState();
    _selectedMethodIds = widget.initialSelectedMethodIds.toSet();
  }

  bool get _canTurnOn => _selectedMethodIds.length >= 2;

  List<String> get _selectedIdsResult => _selectedMethodIds.toList();

  void _toggleMethod(String methodId) {
    setState(() {
      if (_selectedMethodIds.contains(methodId)) {
        _selectedMethodIds.remove(methodId);
      } else {
        _selectedMethodIds.add(methodId);
      }
    });
  }

  void _handleBack() {
    context.pop(
      <String, dynamic>{
        'selectedMethodIds': _selectedIdsResult,
      },
    );
  }

  Future<bool> _handleWillPop() async {
    _handleBack();
    return false;
  }

  void _handleSubmit() {
    if (!_canTurnOn) {
      return;
    }

    context.pop(
      <String, dynamic>{
        'selectedMethodIds': _selectedIdsResult,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: AppColors.colorff19191A,
        appBar: CustomAppBar(
          backgroundColor: AppColors.colorff19191A,
          onLeadingTap: _handleBack,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Two-Factor Authentication',
                  style: TextStyles.titleBig.copyWith(
                    fontSize: 24,
                    height: 1.2,
                    letterSpacing: -0.48,
                    color: AppColors.textBrand,
                  ),
                ),
                const Gap(12),
                Text(
                  'Turning this on will require an additional verification code '
                  'when you log in from an untrusted device.',
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFFA3A3A3),
                    height: 1.4,
                  ),
                ),
                const Gap(48),
                Text(
                  'Select at least 2 methods',
                  style: TextStyles.bodyLarge.copyWith(
                    color: const Color(0xFFA3A3A3),
                    height: 1.4,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final method = _twoFactorMethods[index];
                      return _TwoFactorMethodCard(
                        item: method,
                        isSelected: _selectedMethodIds.contains(method.id),
                        onTap: () => _toggleMethod(method.id),
                      );
                    },
                    separatorBuilder: (_, __) => const Gap(12),
                    itemCount: _twoFactorMethods.length,
                  ),
                ),
                const Gap(20),
                CustomButton(
                  text: 'Turn on',
                  onTap: _handleSubmit,
                  isDisabled: !_canTurnOn,
                  borderRadius: 6,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: TextStyles.titleMain.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
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

class _TwoFactorMethodCard extends StatelessWidget {
  const _TwoFactorMethodCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _TwoFactorMethodItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            crossAxisAlignment: item.description == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    EdgeInsets.only(top: item.description == null ? 0 : 2),
                child: Icon(
                  item.icon,
                  size: 24,
                  color: AppColors.textBrand,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyles.bodyLarge.copyWith(
                        color: AppColors.textBrand,
                        height: 1.4,
                      ),
                    ),
                    if (item.description != null) ...[
                      const Gap(4),
                      Text(
                        item.description!,
                        style: TextStyles.bodyMain.copyWith(
                          fontSize: 14,
                          height: 1.4,
                          color: const Color(0xFFA3A3A3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(12),
              _TwoFactorSelectionIndicator(isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoFactorSelectionIndicator extends StatelessWidget {
  const _TwoFactorSelectionIndicator({
    required this.isSelected,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.backgroundBrandLight
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected
              ? AppColors.backgroundBrandLight
              : const Color(0xFFE8E8E8),
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.textNeutral,
            )
          : null,
    );
  }
}

class _TwoFactorMethodItem {
  const _TwoFactorMethodItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String? description;
  final IconData icon;
}
