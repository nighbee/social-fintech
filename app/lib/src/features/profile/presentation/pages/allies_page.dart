import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:app/src/features/profile/presentation/mixins/show_sort_bottom_sheet.dart';
import 'package:flutter/material.dart';
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
  String _selectedSort = 'По умолчанию';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackBackground,
      appBar: AppBar(
        backgroundColor: AppColors.blackBackground,
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
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF6D6D6D).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF656565)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.icons.personFavourites.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      const Color(0xFFCACACA),
                      BlendMode.srcIn,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    '0',
                    style: TextStyles.titleTag.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),
        ],
      ),
      body: BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
        bloc: getIt<ProfileBloc>(),
        starterEvent: const ProfileEvent.loadCurrentUserAllies(),
        builder: (context, state, bloc) {
          return Column(
            children: [
              _SearchBar(
                controller: _searchController,
                onChanged: (_) {},
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
              const Gap(16),
              Expanded(
                child: state.when(
                  initial: () => const SizedBox(),
                  loading: (viewModel) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  loadingError: (message) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const Gap(16),
                        Text(
                          message,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  loaded: (viewModel) {
                    if (viewModel.allies.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: const Color(0xFF6D6D6D),
                              size: 64,
                            ),
                            const Gap(16),
                            Text(
                              'У вас пока нет союзников',
                              style: TextStyles.bodyMain.copyWith(
                                color: const Color(0xFF6D6D6D),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: viewModel.allies.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFF333333), height: 1),
                      itemBuilder: (context, index) {
                        final ally = viewModel.allies[index];
                        return _AllyCard(ally: ally);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
