import 'package:app/src/core/base/base_bloc/bloc/base_bloc_widget.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/nav_bars/custom_nav_bar.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/widgets/feed_app_bar.dart';
import 'package:app/src/features/home/presentation/widgets/post_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.colorff19191A,
      appBar: FeedAppBar(
        onCreatePostTap: () => context.push(RoutePaths.createPost),
      ),
      bottomNavigationBar: const CustomNavBar(currentTab: RoutePaths.home),
      body: SafeArea(
        child: BaseBlocWidget<HomeBloc, HomeEvent, HomeState>(
          bloc: getIt<HomeBloc>(),
          starterEvent: const HomeEvent.loadPosts(),
          builder: (context, state, bloc) {
            return state.when(
              initial: () => const Center(child: CircularProgressIndicator()),
              loading: (_) => const Center(child: CircularProgressIndicator()),
              loaded: (viewModel) {
                if (viewModel.posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: AppColors.colorff9CA3AF,
                        ),
                        const Gap(16),
                        Text(
                          'No posts yet',
                          style: TextStyles.titleHeadline.copyWith(
                            color: AppColors.colorff9CA3AF,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  separatorBuilder: (context, index) => Gap(18),
                  padding: const EdgeInsets.all(16),
                  itemCount: viewModel.posts.length,
                  itemBuilder: (context, index) {
                    final post = viewModel.posts[index];
                    return PostCardWidget(post: post);
                  },
                );
              },
              loadingError: (message) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: AppColors.colorffEF4444),
                    const Gap(16),
                    Text(
                      'Error loading posts',
                      style: TextStyles.titleHeadline.copyWith(
                        color: AppColors.colorffEF4444,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      message,
                      style: TextStyles.bodyMain.copyWith(
                        color: AppColors.colorff9CA3AF,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
