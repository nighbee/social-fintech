import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_sort_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

part '../widgets/allies/search_bar.dart';
part '../widgets/allies/sort_button.dart';
part '../widgets/allies/ally_card.dart';
part '../widgets/allies/avatar.dart';
part '../widgets/allies/ally_info.dart';

class AlliesPage extends StatefulWidget {
  const AlliesPage({super.key});

  @override
  State<AlliesPage> createState() => _AlliesPageState();
}

class _AlliesPageState extends State<AlliesPage> with ShowSortBottomSheet {
  String _selectedSort = 'Default: Earliest';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getIt<ProfileBloc>().add(const ProfileEvent.loadCurrentUserAllies());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AllyProfileEntity> _getAllies(ProfileState state) {
    return state.whenOrNull(
          loading: (viewModel) => viewModel.allies,
          loaded: (viewModel) => viewModel.allies,
        ) ??
        const <AllyProfileEntity>[];
  }

  int _getAlliesCount(ProfileState state) => _getAllies(state).length;

  List<AllyProfileEntity> _getVisibleAllies(ProfileState state) {
    final query = _searchController.text.trim().toLowerCase();
    var allies = _getAllies(state).where((ally) {
      if (query.isEmpty) return true;
      final haystack =
          '${ally.displayName} ${ally.rankTier} ${ally.reputationScore}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    if (_selectedSort == 'Default: Latest') {
      allies = allies.reversed.toList();
    }

    return allies;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      bloc: getIt<ProfileBloc>(),
      builder: (context, state) {
        final alliesCount = _getAlliesCount(state);
        final visibleAllies = _getVisibleAllies(state);
        final hasSearchQuery = _searchController.text.trim().isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.colorff19191A,
          appBar: AppBar(
            backgroundColor: AppColors.colorff19191A,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Allies',
              style: TextStyles.titleMain.copyWith(color: Colors.white),
            ),
            centerTitle: true,
            actions: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.colorffE5E5E5.withOpacity(0.85),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Assets.icons.personFavourites.svg(
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        AppColors.colorffE5E5E5,
                        BlendMode.srcIn,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      '$alliesCount',
                      style: TextStyles.bodyMain.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                        color: AppColors.colorffE5E5E5,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(20),
            ],
          ),
          body: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
              _SortButton(
                selectedSort: _selectedSort,
                onTap: () {
                  showSortBottomSheet(
                    context,
                    selectedSort: _selectedSort,
                    onSortChanged: (value) {
                      setState(() {
                        _selectedSort = value;
                      });
                    },
                  );
                },
              ),
              Expanded(
                child: state.when(
                  initial: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  loading: (viewModel) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  loadingError: (message) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red,
                            size: 48,
                          ),
                          const Gap(16),
                          Text(
                            message,
                            style: TextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  loaded: (viewModel) {
                    if (visibleAllies.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                color: AppColors.colorff838383,
                                size: 56,
                              ),
                              const Gap(14),
                              Text(
                                hasSearchQuery
                                    ? 'No allies match your search.'
                                    : 'No allies yet.',
                                style: TextStyles.bodyLarge.copyWith(
                                  color: AppColors.colorffE5E5E5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Gap(6),
                              Text(
                                hasSearchQuery
                                    ? 'Try another name or rank.'
                                    : 'People you follow will appear here.',
                                style: TextStyles.bodyMain.copyWith(
                                  fontSize: 12,
                                  height: 15 / 12,
                                  color: const Color(0xFFA3A3A3),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        for (var i = 0; i < visibleAllies.length; i++) ...[
                          _AllyCard(ally: visibleAllies[i]),
                          if (i != visibleAllies.length - 1) const Gap(16),
                        ],
                        const Gap(16),
                        Text(
                          'You can see posts from people you follow. Follower counts are private.',
                          style: TextStyles.bodyMain.copyWith(
                            fontSize: 12,
                            height: 15 / 12,
                            color: const Color(0xFFA3A3A3),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
