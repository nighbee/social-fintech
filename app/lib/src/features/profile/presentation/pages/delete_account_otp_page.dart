import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/code_input_field.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/features/profile/data/sources/remote/i_interaction_settings_remote.dart';
import 'package:app/src/features/profile/presentation/models/delete_account_flow_data.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class DeleteAccountOtpPage extends StatefulWidget {
  const DeleteAccountOtpPage({
    super.key,
    required this.flowData,
  });

  final DeleteAccountFlowData flowData;

  @override
  State<DeleteAccountOtpPage> createState() => _DeleteAccountOtpPageState();
}

class _DeleteAccountOtpPageState extends State<DeleteAccountOtpPage> {
  final IInteractionSettingsRemote _remote =
      getIt<IInteractionSettingsRemote>();
  String _code = '';
  bool _isNavigating = false;
  int _codeFieldVersion = 0;

  void _handleCodeChanged(String code) {
    if (_code == code) {
      return;
    }

    setState(() {
      _code = code;
    });

    if (code.length == 4 && !_isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _openConfirmPage();
      });
    }
  }

  Future<void> _openConfirmPage() async {
    if (_code.length != 4 || _isNavigating) {
      return;
    }

    _isNavigating = true;
    final verifyResult = await _remote.deleteAccountVerify(otp: _code.trim());
    if (!mounted) {
      return;
    }
    String? verificationToken;
    verifyResult.fold(
      (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      },
      (v) => verificationToken = v.verificationToken,
    );
    if (verificationToken == null || verificationToken!.isEmpty) {
      _isNavigating = false;
      setState(() {
        _code = '';
        _codeFieldVersion++;
      });
      return;
    }
    final result = await context.pushNamed(
      RouteNames.profileSecurityDeleteAccountConfirm,
      extra: widget.flowData
          .copyWith(verificationToken: verificationToken)
          .toExtra(),
    );
    _isNavigating = false;

    if (!mounted) {
      return;
    }

    if (result == true) {
      context.pop(true);
      return;
    }

    setState(() {
      _code = '';
      _codeFieldVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: const CustomAppBar(
        backgroundColor: AppColors.colorff19191A,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the code',
                    style: TextStyles.bodyLarge.copyWith(
                      fontSize: 32,
                      height: 1.2,
                      color: AppColors.textBrand,
                    ),
                  ),
                  const Gap(12),
                  Text(
                    'Enter the code we\'ve sent by SMS to '
                    '${widget.flowData.resolvedPhoneNumber}:',
                    style: TextStyles.bodyMain.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: const Color(0xFFA3A3A3),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: _DeleteAccountOtpArtwork(),
                  ),
                  Transform.scale(
                    scale: 1.14,
                    child: CodeInputField(
                      key: ValueKey(_codeFieldVersion),
                      length: 4,
                      onChanged: _handleCodeChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountOtpArtwork extends StatelessWidget {
  const _DeleteAccountOtpArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x0019191A),
            Color(0xFF14171D),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            right: -30,
            bottom: -80,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF232832),
                    Color(0xFF0D0F14),
                  ],
                ),
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
          Positioned(
            left: 34,
            bottom: 98,
            child: _DeleteAccountOtpGlow(
              size: 110,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            right: 26,
            bottom: 54,
            child: _DeleteAccountOtpGlow(
              size: 150,
              color: const Color(0xFF6E768A).withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            left: 118,
            right: 118,
            bottom: 26,
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textBrand,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountOtpGlow extends StatelessWidget {
  const _DeleteAccountOtpGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}
