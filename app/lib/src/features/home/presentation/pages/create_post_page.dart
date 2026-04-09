import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/custom_network_image.dart';
import 'package:app/src/core/widgets/gap_extension.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_visibility_bottom_sheet.dart';
import 'package:app/src/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with ShowPostVisibilityBottomSheet {
  late final HomeBloc _bloc;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final PageController _photoPageController;
  PostVisibilityOption _visibility = PostVisibilityOption.everyone;
  CommentControlOption _commentControl = CommentControlOption.everyone;
  bool _isSubmitting = false;
  int _photoPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<HomeBloc>();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _photoPageController = PageController();
    _bloc.add(const HomeEvent.clearPostPhotos());

    final profileBloc = getIt<ProfileBloc>();
    final shouldLoadProfile = profileBloc.state.maybeWhen(
      initial: () => true,
      loadingError: (_) => true,
      orElse: () => false,
    );
    if (shouldLoadProfile) {
      profileBloc.add(const ProfileEvent.loadProfile());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    await ImagePickerHelper.showImagePicker(
      context: context,
      imageQuality: 60,
      maxWidth: 1280,
      maxHeight: 1280,
      onImageSelected: (bytes, fileName) {
        _bloc.add(HomeEvent.addPostPhoto(bytes, fileName));
      },
    );
  }

  void _submit() {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _bloc.add(HomeEvent.createPost(content: _controller.text.trim()));
  }

  void _syncPhotoPageIndex(int totalPhotos) {
    if (totalPhotos <= 0) {
      if (_photoPageIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _photoPageIndex == 0) return;
          setState(() => _photoPageIndex = 0);
        });
      }
      return;
    }

    if (_photoPageIndex >= totalPhotos) {
      final targetIndex = totalPhotos - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _photoPageIndex = targetIndex);
        if (_photoPageController.hasClients) {
          _photoPageController.jumpToPage(targetIndex);
        }
      });
    }
  }

  void _openVisibilitySheet() {
    showPostVisibilityBottomSheet(
      context,
      selected: _visibility,
      selectedCommentControl: _commentControl,
      onSelected: (value) {
        setState(() => _visibility = value);
      },
      onCommentControlTap: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showCommentControlBottomSheet(
            context,
            selected: _commentControl,
            onSelected: (value) {
              setState(() => _commentControl = value);
            },
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      bloc: _bloc,
      listener: (context, state) {
        state.whenOrNull(
          loadingError: (message) {
            if (_isSubmitting) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          },
          loaded: (viewModel) {
            if (_isSubmitting) {
              setState(() => _isSubmitting = false);
              _controller.clear();
              Navigator.of(context).pop();
            }
          },
        );
      },
      builder: (context, state) {
        final viewModel = state.maybeWhen(
          loading: (viewModel) => viewModel,
          loaded: (viewModel) => viewModel,
          orElse: HomeViewModel.new,
        );
        _syncPhotoPageIndex(viewModel.postComposerPhotos.length);
        final canSubmit = _controller.text.trim().isNotEmpty ||
            viewModel.postComposerPhotos.isNotEmpty;
        final profile = getIt<ProfileBloc>().state.maybeWhen(
              loading: (viewModel) => viewModel.profile,
              loaded: (viewModel) => viewModel.profile,
              orElse: () => ProfileViewModel().profile,
            );
        final composerAvatarUrl = profile.avatarUrl.trim();
        final displayName = profile.displayName.trim();
        final fallbackInitial = profile.displayName.trim().isNotEmpty
            ? displayName[0].toUpperCase()
            : 'A';

        return Scaffold(
          backgroundColor: AppColors.mainBackground,
          appBar: AppBar(
            backgroundColor: AppColors.mainBackground,
            elevation: 0,
            leadingWidth: 48,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: composerAvatarUrl.isNotEmpty
                      ? CustomNetworkImage(
                          imageUrl: composerAvatarUrl,
                          width: 30,
                          height: 30,
                        )
                      : Container(
                          width: 30,
                          height: 30,
                          color: AppColors.surface,
                          alignment: Alignment.center,
                          child: Text(
                            fallbackInitial,
                            style: TextStyles.bodyMain.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const Gap(10),
                InkWell(
                  onTap: () => _openVisibilitySheet(),
                  child: Row(
                    children: [
                      Text(
                        _visibility == PostVisibilityOption.everyone
                            ? 'Anyone'
                            : _visibility.label,
                        style: TextStyles.bodyLarge.copyWith(
                          color: Colors.white,
                          fontSize: 26 / 1.8,
                        ),
                      ),
                      const Gap(4),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF5B5B5E),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      _isSubmitting ? 'Posting...' : 'Post',
                      style: TextStyles.bodyLarge.copyWith(
                        color: canSubmit ? Colors.black : Colors.white70,
                        fontSize: 24 / 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: null,
                      onChanged: (_) => setState(() {}),
                      style: TextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontSize: 19,
                        height: 1.35,
                      ),
                      cursorColor: Colors.white70,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Share something valuable',
                        hintStyle: TextStyles.bodyLarge.copyWith(
                          color: AppColors.textGray2,
                          fontSize: 19,
                        ),
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const Gap(16),
                    if (viewModel.postComposerPhotos.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (context) {
                            final totalPhotos =
                                viewModel.postComposerPhotos.length;
                            final currentIndex =
                                _photoPageIndex.clamp(0, totalPhotos - 1);

                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 460,
                                    child: PageView.builder(
                                      controller: _photoPageController,
                                      itemCount: totalPhotos,
                                      onPageChanged: (index) {
                                        if (_photoPageIndex != index) {
                                          setState(() => _photoPageIndex = index);
                                        }
                                      },
                                      itemBuilder: (context, index) {
                                        return Image.memory(
                                          viewModel
                                              .postComposerPhotos[index].bytes,
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => _bloc.add(
                                      HomeEvent.removePostPhoto(
                                        viewModel
                                            .postComposerPhotos[currentIndex]
                                            .fileName,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: Row(
                                    children: const [
                                      _PhotoOverlayChip(
                                        label: '+ALT',
                                        horizontalPadding: 9,
                                      ),
                                      Gap(8),
                                      _PhotoOverlayChip(
                                        icon: Icons.edit_outlined,
                                        horizontalPadding: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                if (totalPhotos > 1)
                                  Positioned(
                                    left: 10,
                                    bottom: 10,
                                    child: _PhotoOverlayChip(
                                      label:
                                          '${currentIndex + 1}/$totalPhotos',
                                      horizontalPadding: 9,
                                    ),
                                  ),
                              ],
                            );
                          }),
                          const Gap(10),
                          _PostMetaAction(
                            icon: Assets.icons.personSearch.svg(
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Colors.white70,
                                BlendMode.srcIn,
                              ),
                            ),
                            label: 'Tag people',
                          ),
                          const Gap(10),
                          _PostMetaAction(
                            icon: Assets.icons.location.svg(
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(
                                Colors.white70,
                                BlendMode.srcIn,
                              ),
                            ),
                            label: 'Add location',
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _pickPhoto,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Assets.icons.images.svg(
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white70,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 22,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ].addGap(10),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PostMetaAction extends StatelessWidget {
  const _PostMetaAction({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const Gap(8),
        Text(
          label,
          style: TextStyles.bodyLarge.copyWith(
            color: Colors.white70,
            fontSize: 26 / 1.8,
          ),
        ),
      ],
    );
  }
}

class _PhotoOverlayChip extends StatelessWidget {
  const _PhotoOverlayChip({
    this.label,
    this.icon,
    this.horizontalPadding = 8,
  });

  final String? label;
  final IconData? icon;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: label != null
          ? Text(
              label!,
              style: TextStyles.bodyMain.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(icon, size: 14, color: Colors.white),
    );
  }
}
