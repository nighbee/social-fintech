import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/features/profile/domain/entities/ally_profile_entity.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AlliesPage extends StatefulWidget {
  const AlliesPage({super.key});

  @override
  State<AlliesPage> createState() => _AlliesPageState();
}

class _AlliesPageState extends State<AlliesPage> {
  String _selectedSort = 'По умолчанию';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getAlliesCount(ProfileState state) {
    return state.whenOrNull(loaded: (viewModel) => viewModel.allies.length) ??
        0;
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
          'Союзники',
          style: TextStyles.titleMain.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const Gap(6),
                Text(
                  '0',
                  style: TextStyles.bodyMain.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BaseBlocWidget<ProfileBloc, ProfileEvent, ProfileState>(
        bloc: getIt<ProfileBloc>(),
        starterEvent: const ProfileEvent.loadCurrentUserAllies(),
        builder: (context, state, bloc) {
          final alliesCount = _getAlliesCount(state);

          return Column(
            children: [
              _SearchBar(controller: _searchController),
              _SortDropdown(
                selectedSort: _selectedSort,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSort = value;
                    });
                  }
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
                              color: Color(0xFF6D6D6D),
                              size: 64,
                            ),
                            Gap(16),
                            Text(
                              'У вас пока нет союзников',
                              style: TextStyles.bodyMain.copyWith(
                                color: Color(0xFF6D6D6D),
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
                        return AllyCard(ally: ally);
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        style: TextStyles.bodyMain.copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Поиск',
          hintStyle: TextStyles.bodyMain.copyWith(
            color: const Color(0xFF6D6D6D),
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D6D6D)),
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  final String selectedSort;
  final void Function(String?) onChanged;

  const _SortDropdown({required this.selectedSort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Сортировать по',
            style: TextStyles.bodyMain.copyWith(color: const Color(0xFF6D6D6D)),
          ),
          const Gap(8),
          DropdownButton<String>(
            value: selectedSort,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: Color(0xFF6D6D6D),
            ),
            style: TextStyles.bodyMain.copyWith(color: const Color(0xFF6D6D6D)),
            items: const [
              DropdownMenuItem(
                value: 'По умолчанию',
                child: Text('По умолчанию'),
              ),
              DropdownMenuItem(value: 'Новые', child: Text('Новые')),
              DropdownMenuItem(
                value: 'По имени А-Я',
                child: Text('По имени А-Я'),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class AllyCard extends StatelessWidget {
  final AllyProfileEntity ally;

  const AllyCard({super.key, required this.ally});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _Avatar(imageUrl: ally.avatarUrl),
          const Gap(12),
          Expanded(child: _AllyInfo(ally: ally)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String imageUrl;

  const _Avatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 48,
            height: 48,
            color: const Color(0xFF333333),
            child: const Icon(Icons.person, color: Color(0xFF6D6D6D), size: 24),
          );
        },
      ),
    );
  }
}

class _AllyInfo extends StatelessWidget {
  final AllyProfileEntity ally;

  const _AllyInfo({required this.ally});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ally.displayName,
          style: TextStyles.bodyMain.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(4),
        Row(
          children: [
            Text(
              ally.rankTier,
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFF5E8DFF),
              ),
            ),
            Text(
              ' · ',
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFF6D6D6D),
              ),
            ),
            Text(
              '${ally.reputationScore}',
              style: TextStyles.bodySecondary.copyWith(
                color: const Color(0xFFFFA500),
              ),
            ),
            const Gap(4),
            const Icon(Icons.star, size: 14, color: Color(0xFFFFA500)),
          ],
        ),
      ],
    );
  }
}
