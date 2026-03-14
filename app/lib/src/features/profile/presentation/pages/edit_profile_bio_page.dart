import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/requests/update_profile_request.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/widgets/edit_profile/edit_profile_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class EditProfileBioPage extends StatefulWidget {
  const EditProfileBioPage({
    super.key,
    required this.initialBio,
  });

  final String initialBio;

  @override
  State<EditProfileBioPage> createState() => _EditProfileBioPageState();
}

class _EditProfileBioPageState extends State<EditProfileBioPage> {
  static const int _maxLength = 500;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialBio);
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

  String get _currentBio => _controller.text;

  bool get _canSave {
    if (_isSaving) {
      return false;
    }
    return _currentBio != widget.initialBio;
  }

  void _saveBio() {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    getIt<ProfileBloc>().add(
      ProfileEvent.updateProfile(
        UpdateProfileRequest(bio: _currentBio),
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
        context.pop(_currentBio);
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
          onActionTap: _saveBio,
          isActionEnabled: _canSave,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EditProfileSectionLabel(title: 'Bio'),
                const Gap(16),
                EditProfileBioInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  maxLength: _maxLength,
                ),
                const Gap(8),
                EditProfileCounterText(
                  currentLength: _currentBio.length,
                  maxLength: _maxLength,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
