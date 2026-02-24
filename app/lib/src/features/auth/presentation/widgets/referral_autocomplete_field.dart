import 'dart:async';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/auth/domain/entities/user_search_entity.dart';
import 'package:app/src/features/auth/domain/requests/search_users_request.dart';
import 'package:app/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';

class ReferralAutocompleteField extends StatefulWidget {
  const ReferralAutocompleteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.searchData,
    required this.isSearchLoading,
    required this.validateNickname,
    required this.formKey,
    required this.validator,
    required this.onSelectedUser,
    required this.onInputChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<UserSearchEntity> searchData;
  final bool isSearchLoading;
  final bool validateNickname;
  final GlobalKey<FormState> formKey;
  final String? Function(String?) validator;
  final ValueChanged<UserSearchEntity> onSelectedUser;
  final ValueChanged<String> onInputChanged;

  @override
  State<ReferralAutocompleteField> createState() =>
      _ReferralAutocompleteFieldState();
}

class _ReferralAutocompleteFieldState extends State<ReferralAutocompleteField> {
  Timer? _searchTimer;
  String _lastQuery = '';

  void _validateIfNeeded() {
    if (widget.validateNickname) {
      widget.formKey.currentState?.validate();
    }
  }

  void _triggerSearch(String value) {
    _searchTimer?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      _lastQuery = '';
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_lastQuery == query) return;
      _lastQuery = query;

      final parts = query.split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      getIt<AuthBloc>().add(
        AuthEvent.searchUsers(
          request: SearchUsersRequest(
            firstName: firstName,
            lastName: lastName,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<UserSearchEntity>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      displayStringForOption: (option) =>
          '${option.firstName} ${option.lastName}'.trim(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim();
        if (query.isEmpty) {
          return const Iterable<UserSearchEntity>.empty();
        }
        return widget.searchData;
      },
      onSelected: (UserSearchEntity selection) {
        final fullName = '${selection.firstName} ${selection.lastName}'.trim();
        widget.controller.text = fullName;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: fullName.length),
        );
        widget.onSelectedUser(selection);
        _validateIfNeeded();
        setState(() {});
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return CustomTextField(
          controller: controller,
          focusNode: focusNode,
          labelText: 'Nickname',
          hintText: '',
          validator: widget.validator,
          prefixIcon: Assets.icons.atsign.svg(
            width: 30,
            height: 30,
            colorFilter: const ColorFilter.mode(
              AppColors.whiteBackground,
              BlendMode.srcIn,
            ),
          ),
          suffixIcon: widget.isSearchLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          controller.clear();
                        });
                        _lastQuery = '';
                        widget.onInputChanged('');
                        _validateIfNeeded();
                      },
                      child: Assets.icons.close.svg(
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          AppColors.textGray2,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : null,
          onChanged: (value) {
            setState(() {});
            widget.onInputChanged(value);
            _validateIfNeeded();
            _triggerSearch(value);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox?;
        final overlaySize = overlay?.size ?? MediaQuery.of(context).size;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: overlaySize.width,
                maxHeight: 260,
              ),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: context.theme.mainBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textGray2.withOpacity(0.25),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: options.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          'No users found',
                          style: TextStyles.bodyLarge.copyWith(
                            color: AppColors.whiteBackground,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColors.textGray2.withOpacity(0.2),
                        ),
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Text(
                                "${option.firstName} ${option.lastName}",
                                style: TextStyles.bodyLarge.copyWith(
                                  color: AppColors.whiteBackground,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
