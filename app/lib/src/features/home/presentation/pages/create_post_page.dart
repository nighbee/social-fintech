import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
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
  late final HomeBloc _bloc;
  late final TextEditingController _controller;
  PostVisibilityOption _visibility = PostVisibilityOption.everyone;
  CommentControlOption _commentControl = CommentControlOption.everyone;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<HomeBloc>();
    _controller = TextEditingController();
    _bloc.add(const HomeEvent.clearPostPhotos());
  }

  @override
  void dispose() {
    _controller.dispose();
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
    _isSubmitting = true;
    _bloc.add(HomeEvent.createPost(content: _controller.text));
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
              _isSubmitting = false;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            }
          },
          loaded: (viewModel) {
            if (_isSubmitting) {
              _isSubmitting = false;
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
          backgroundColor: AppColors.colorff19191A,
          appBar: AppBar(
            backgroundColor: AppColors.colorff19191A,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: InkWell(
              onTap: _openVisibilitySheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _visibility == PostVisibilityOption.everyone
                        ? 'Anyone'
                        : _visibility.label,
                    style: TextStyles.titleTag.copyWith(color: Colors.white),
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
            actions: [
              TextButton(
                onPressed: canSubmit ? _submit : null,
                child: Text(
                  'Post',
                  style: TextStyles.titleTag.copyWith(
                    color: canSubmit ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                CustomTextField(
                  controller: _controller,
                  labelText: 'Share something...',
                  showLabel: false,
                  // minLines: 5,
                  // maxLines: 8,
                  onChanged: (_) => setState(() {}),
                ),
                const Gap(12),
                if (viewModel.postComposerPhotos.isNotEmpty)
                  SizedBox(
                    height: 95,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: viewModel.postComposerPhotos.length,
                      separatorBuilder: (_, __) => const Gap(8),
                      itemBuilder: (context, index) {
                        final photo = viewModel.postComposerPhotos[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                photo.bytes,
                                width: 95,
                                height: 95,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _bloc.add(
                                  HomeEvent.removePostPhoto(photo.fileName),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const Gap(12),
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.colorff2A2A2B,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.colorff3F3F40),
                        ),
                        child: Assets.icons.plusIcon.svg(width: 20, height: 20),
                      ),
                    ),
                    Text(
                      'Photo',
                      style: TextStyles.titleTag.copyWith(color: Colors.white),
                    ),
                  ].addGap(8),
                ),
                const Spacer(),
              ],
            ),
          ),
        );
      },
    );
  }
}
