import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/repositories/i_profile_repository.dart';
import 'package:app/src/features/profile/domain/requests/search_profiles_request.dart';
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
    required this.currentUserId,
  });

  final String initialDisplayName;
  final String currentUserId;

  @override
  State<EditProfileNicknamePage> createState() =>
      _EditProfileNicknamePageState();
}

class _EditProfileNicknamePageState extends State<EditProfileNicknamePage> {
  static const int _maxLength = 50;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  IProfileRepository? _profileRepository;
  late final String _initialSanitizedDisplayName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    try {
      _profileRepository = getIt<IProfileRepository>();
    } catch (_) {
      _profileRepository = null;
    }
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

  String _normalizeNickname(String value) {
    return _sanitizeDisplayName(value).toLowerCase();
  }

  bool _isConflictError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('409') ||
        normalized.contains('conflict') ||
        normalized.contains('already exists') ||
        normalized.contains('duplicate') ||
        normalized.contains('display_name_taken') ||
        normalized.contains('username_taken');
  }

  Future<bool> _isNicknameTaken(String candidate) async {
    final repository = _profileRepository;
    if (repository == null) {
      return false;
    }

    final result = await repository.searchProfiles(
      SearchProfilesRequest(query: candidate, limit: 20, offset: 0),
    );

    return result.fold((_) => false, (items) {
      final normalizedCandidate = _normalizeNickname(candidate);
      return items.any((item) {
        final isSameUser = item.userId == widget.currentUserId;
        if (isSameUser) {
          return false;
        }
        return _normalizeNickname(item.displayName) == normalizedCandidate;
      });
    });
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

  Future<void> _saveNickname() async {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final isTaken = await _isNicknameTaken(_sanitizedValue);
      if (!mounted) {
        return;
      }

      if (isTaken) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This nickname is already taken. Choose another one.'),
          ),
        );
        return;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to validate nickname right now. Try again.'),
        ),
      );
      return;
    }

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

        final resolvedMessage = _isConflictError(message)
            ? 'This nickname is already taken. Choose another one.'
            : message;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resolvedMessage)),
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
