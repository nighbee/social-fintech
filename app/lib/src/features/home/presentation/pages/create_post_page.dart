import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/gap_extension.dart';
import 'package:app/src/features/home/presentation/bloc/home_bloc.dart';
import 'package:app/src/features/home/presentation/mixins/show_post_visibility_bottom_sheet.dart';
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
  static const String _composerAvatarUrl = 'https://i.pravatar.cc/120?img=1';

  late final HomeBloc _bloc;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  PostVisibilityOption _visibility = PostVisibilityOption.everyone;
  CommentControlOption _commentControl = CommentControlOption.everyone;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<HomeBloc>();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _bloc.add(const HomeEvent.clearPostPhotos());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    await ImagePickerHelper.showImagePicker(
      context: context,
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
        final canSubmit = _controller.text.trim().isNotEmpty ||
            viewModel.postComposerPhotos.isNotEmpty;

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
                  child: Image.network(
                    _composerAvatarUrl,
                    width: 30,
                    height: 30,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 30,
                      height: 30,
                      color: AppColors.surface,
                      alignment: Alignment.center,
                      child: Text(
                        'A',
                        style: TextStyles.bodyMain.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  viewModel.postComposerPhotos.first.bytes,
                                  width: double.infinity,
                                  height: 460,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _bloc.add(
                                    HomeEvent.removePostPhoto(
                                      viewModel
                                          .postComposerPhotos.first.fileName,
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
                              if (viewModel.postComposerPhotos.length > 1)
                                Positioned(
                                  left: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${viewModel.postComposerPhotos.length - 1}',
                                      style: TextStyles.bodyMain.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
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
