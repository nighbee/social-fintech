import 'dart:async';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/features/home/domain/entities/profile_search_recent_item_entity.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/profile/domain/entities/profile_search_result_entity.dart';
import 'package:app/src/features/profile/domain/requests/search_profiles_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  _SearchPageState();

  static const Duration _searchDebounce = Duration(milliseconds: 350);

  final HomeBloc _bloc = getIt<HomeBloc>();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  bool get _showsCancelButton =>
      _focusNode.hasFocus || _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _bloc.add(const HomeEvent.clearProfileSearch());
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _bloc.add(const HomeEvent.clearProfileSearch());
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    final normalized = value.trim().replaceFirst(RegExp(r'^@+'), '');
    if (normalized.isEmpty) {
      _bloc.add(const HomeEvent.clearProfileSearch());
      setState(() {});
      return;
    }

    _debounceTimer = Timer(_searchDebounce, () {
      _bloc.add(
        HomeEvent.searchProfiles(
          request: SearchProfilesRequest(query: normalized),
        ),
      );
    });
    setState(() {});
  }

  void _onCancelTap() {
    _debounceTimer?.cancel();
    _controller.clear();
    _focusNode.unfocus();
    _bloc.add(const HomeEvent.clearProfileSearch());
    context.pop();
  }

  void _openPublicProfile(ProfileSearchResultEntity result) {
    if (result.userId.isEmpty) return;
    _bloc.add(HomeEvent.addProfileSearchRecent(result: result));
    _focusNode.unfocus();
    context.pushNamed(
      RouteNames.publicProfile,
      pathParameters: {'userId': result.userId},
    );
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
        final trimmedQuery = _controller.text.trim();
        final showsRecent = trimmedQuery.isEmpty;

        return Scaffold(
          backgroundColor: AppColors.colorff19191A,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                const _SearchPageAtmosphere(),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: _SearchTopBar(
                          controller: _controller,
                          focusNode: _focusNode,
                          showCancelButton: _showsCancelButton,
                          onChanged: _onQueryChanged,
                          onCancelTap: _onCancelTap,
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                          child: showsRecent
                              ? _RecentSearchSection(
                                  items: viewModel.profileSearchRecentItems,
                                  onUserTap: _openPublicProfile,
                                  onRemoveItem: (userId) {
                                    _bloc.add(
                                      HomeEvent.removeProfileSearchRecent(
                                        userId: userId,
                                      ),
                                    );
                                  },
                                  onClearAll: () => _bloc.add(
                                    const HomeEvent.clearProfileSearchRecent(),
                                  ),
                                )
                              : _SearchResultsSection(
                                  query: trimmedQuery,
                                  isLoading: viewModel.isProfileSearchLoading,
                                  errorMessage: viewModel.profileSearchError,
                                  results: viewModel.profileSearchResults,
                                  onUserTap: _openPublicProfile,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchPageAtmosphere extends StatelessWidget {
  const _SearchPageAtmosphere();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.colorff19191A,
              gradient: RadialGradient(
                center: const Alignment(0, -0.9),
                radius: 1.15,
                colors: [
                  const Color(0xFF232427).withValues(alpha: 0.85),
                  AppColors.colorff19191A,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          left: -30,
          right: -30,
          child: IgnorePointer(
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.48),
                    Colors.black.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 64,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchTopBar extends StatelessWidget {
  const _SearchTopBar({
    required this.controller,
    required this.focusNode,
    required this.showCancelButton,
    required this.onChanged,
    required this.onCancelTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showCancelButton;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancelTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CustomTextField(
            controller: controller,
            focusNode: focusNode,
            labelText: 'Search',
            hintText: 'Search',
            onChanged: onChanged,
            showLabel: false,
            showBorder: false,
            backgroundColor: const Color(0xFF1E1E1E),
            height: 48,
            borderRadius: 10,
            containerPadding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: TextStyles.bodyMain.copyWith(
              fontSize: 16,
              color: AppColors.colorffffffff,
            ),
            hintStyle: TextStyles.bodyMain.copyWith(
              fontSize: 16,
              color: const Color(0xFFBABABA),
            ),
            prefixIcon: Assets.icons.search.svg(
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.colorffE5E5E5,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: showCancelButton
              ? Padding(
                  key: const ValueKey('cancel'),
                  padding: const EdgeInsets.only(left: 12),
                  child: GestureDetector(
                    onTap: onCancelTap,
                    child: Text(
                      'Cancel',
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 16,
                        color: const Color(0xFFBABABA),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}

class _RecentSearchSection extends StatelessWidget {
  const _RecentSearchSection({
    required this.items,
    required this.onUserTap,
    required this.onRemoveItem,
    required this.onClearAll,
  });

  final List<ProfileSearchRecentItemEntity> items;
  final ValueChanged<ProfileSearchResultEntity> onUserTap;
  final ValueChanged<String> onRemoveItem;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _SearchEmptyState(
        title: 'Recent',
        message: 'Recent people you open will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchSectionHeader(
          title: 'Recent',
          actionLabel: 'Clear All',
          onActionTap: onClearAll,
        ),
        const Gap(12),
        for (var index = 0; index < items.length; index++) ...[
          _SearchUserCard(
            profile: items[index].profile,
            timeLabel: _formatRelativeTime(items[index].searchedAt),
            onTap: () => onUserTap(items[index].profile),
            onTrailingTap: () => onRemoveItem(items[index].profile.userId),
          ),
          if (index != items.length - 1) const Gap(12),
        ],
      ],
    );
  }

  static String _formatRelativeTime(DateTime searchedAt) {
    final diff = DateTime.now().difference(searchedAt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class _SearchResultsSection extends StatelessWidget {
  const _SearchResultsSection({
    required this.query,
    required this.isLoading,
    required this.errorMessage,
    required this.results,
    required this.onUserTap,
  });

  final String query;
  final bool isLoading;
  final String errorMessage;
  final List<ProfileSearchResultEntity> results;
  final ValueChanged<ProfileSearchResultEntity> onUserTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return _SearchEmptyState(
        title: 'Users',
        message: errorMessage,
      );
    }

    if (results.isEmpty) {
      return _SearchEmptyState(
        title: 'Users',
        message: 'No users found for "$query".',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SearchSectionHeader(title: 'Users'),
        const Gap(12),
        for (var index = 0; index < results.length; index++) ...[
          _SearchUserCard(
            profile: results[index],
            onTap: () => onUserTap(results[index]),
          ),
          if (index != results.length - 1) const Gap(12),
        ],
      ],
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyles.titleMain.copyWith(
            fontSize: 16,
            color: AppColors.colorffffffff,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onActionTap != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: TextStyles.bodyMain.copyWith(
                fontSize: 16,
                color: const Color(0xFF74AFE3),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchUserCard extends StatelessWidget {
  const _SearchUserCard({
    required this.profile,
    required this.onTap,
    this.timeLabel,
    this.onTrailingTap,
  });

  final ProfileSearchResultEntity profile;
  final VoidCallback onTap;
  final String? timeLabel;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF223446).withValues(alpha: 0.24),
              Colors.white.withValues(alpha: 0.02),
              const Color(0xFF5B3D1E).withValues(alpha: 0.16),
            ],
          ),
        ),
        child: Row(
          children: [
            _SearchAvatar(profile: profile),
            const Gap(12),
            Expanded(
              child: _SearchUserInfo(
                profile: profile,
                timeLabel: timeLabel,
              ),
            ),
            if (onTrailingTap != null)
              GestureDetector(
                onTap: onTrailingTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchAvatar extends StatelessWidget {
  const _SearchAvatar({required this.profile});

  final ProfileSearchResultEntity profile;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile.avatarUrl.trim();
    if (imageUrl.isNotEmpty) {
      return CustomNetworkImage(
        imageUrl: imageUrl,
        width: 40,
        height: 40,
        borderRadius: BorderRadius.circular(4),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 20,
        color: AppColors.colorff9CA3AF,
      ),
    );
  }
}

class _SearchUserInfo extends StatelessWidget {
  const _SearchUserInfo({
    required this.profile,
    this.timeLabel,
  });

  final ProfileSearchResultEntity profile;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bodyMain.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colorffffffff,
                ),
              ),
            ),
            if (timeLabel != null) ...[
              const Gap(8),
              Text(
                timeLabel!,
                style: TextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: AppColors.colorffE5E5E5,
                ),
              ),
            ],
          ],
        ),
        const Gap(4),
        Row(
          children: [
            Flexible(
              child: Text(
                profile.rankTier,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF74AFE3),
                ),
              ),
            ),
            const Gap(6),
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Color(0xFF74AFE3),
                shape: BoxShape.circle,
              ),
            ),
            const Gap(6),
            Text(
              profile.reputationScore.toString(),
              style: TextStyles.bodySecondary.copyWith(
                fontSize: 12,
                color: const Color(0xFF74AFE3),
              ),
            ),
            const Gap(4),
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Color(0xFF74AFE3),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SearchSectionHeader(title: title),
        const Gap(16),
        Text(
          message,
          style: TextStyles.bodyMain.copyWith(
            fontSize: 14,
            height: 1.4,
            color: const Color(0xFFA3A3A3),
          ),
        ),
      ],
    );
  }
}
