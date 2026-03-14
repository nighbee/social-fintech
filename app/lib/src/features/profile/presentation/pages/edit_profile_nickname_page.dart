import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/edit_profile_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditProfileNicknamePage extends StatefulWidget {
  const EditProfileNicknamePage({
    super.key,
    required this.initialDisplayName,
  });

  final String initialDisplayName;

  @override
  State<EditProfileNicknamePage> createState() =>
      _EditProfileNicknamePageState();
}

class _EditProfileNicknamePageState extends State<EditProfileNicknamePage> {
  static const int _maxLength = 50;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final String _initialSanitizedDisplayName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initialSanitizedDisplayName = _sanitizeDisplayName(
      widget.initialDisplayName,
    );
    _controller = TextEditingController(text: _initialSanitizedDisplayName);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _sanitizeDisplayName(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.startsWith('@')) {
      return trimmedValue.substring(1).trimLeft();
    }
    return trimmedValue;
  }

  String get _sanitizedValue => _sanitizeDisplayName(_controller.text);

  bool get _canSave {
    if (_isSaving) {
      return false;
    }
    if (_sanitizedValue.isEmpty) {
      return false;
    }
    return _sanitizedValue != _initialSanitizedDisplayName;
  }

  void _saveNickname() {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    getIt<ProfileBloc>().add(
      ProfileEvent.updateProfile(
        UpdateProfileRequest(displayName: _sanitizedValue),
      ),
    );
  }

  void _handleProfileState(ProfileState state) {
    if (!_isSaving) {
      return;
    }

    state.whenOrNull(
      loaded: (_) {
        setState(() {
          _isSaving = false;
        });
        context.pop(_sanitizedValue);
      },
      loadingError: (message) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileBloc, ProfileState>(
      bloc: getIt<ProfileBloc>(),
      listener: (context, state) => _handleProfileState(state),
      child: Scaffold(
        backgroundColor: AppColors.colorff19191A,
        appBar: EditProfileFlowAppBar(
          actionLabel: 'Save',
          onActionTap: _saveNickname,
          isActionEnabled: _canSave,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EditProfileSectionLabel(title: 'Nickname'),
                const Gap(4),
                EditProfileNicknameInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _controller.clear();
                    setState(() {});
                    _focusNode.requestFocus();
                  },
                  maxLength: _maxLength,
                ),
                const Gap(4),
                EditProfileCounterText(
                  currentLength: _sanitizedValue.length,
                  maxLength: _maxLength,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
