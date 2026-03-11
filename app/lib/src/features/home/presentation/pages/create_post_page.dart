import 'dart:typed_data';

import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/image_picker_helper.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/gap_extension.dart';
import 'package:app/src/features/home/domain/models/local_media_payload.dart';
import 'package:app/src/features/home/domain/requests/create_post_request.dart';
import 'package:app/src/features/home/domain/requests/media_attachment_request.dart';
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
    await ImagePickerHelper.showMediaPicker(
      context: context,
      onMediaSelected: (bytes, fileName) {
        _bloc.add(HomeEvent.addPostPhoto(bytes, fileName));
      },
    );
  }

  String _mapVisibility(PostVisibilityOption option) {
    switch (option) {
      case PostVisibilityOption.everyone:
        return 'ANYONE';
      case PostVisibilityOption.allies:
        return 'ALLIES_ONLY';
    }
  }

  String _mapCommentPermission(CommentControlOption option) {
    switch (option) {
      case CommentControlOption.everyone:
        return 'ANYONE';
      case CommentControlOption.allies:
        return 'ALLIES_ONLY';
      case CommentControlOption.nobody:
        return 'NO_ONE';
    }
  }

  void _submit(List<CommentComposerPhoto> photos) {
    _isSubmitting = true;
    final localMediaPayloads = <LocalMediaPayload>[];
    final request = CreatePostRequest(
      caption: _controller.text.trim(),
      mediaAttachments: photos.map(
        (photo) {
          final tokenUrl =
              'local-media://${Uri.encodeComponent(photo.fileName)}';
          localMediaPayloads.add(
            LocalMediaPayload(localUrl: tokenUrl, bytes: photo.bytes),
          );
          return MediaAttachmentRequest(
            type: _isVideoFileName(photo.fileName) ? 'video' : 'image',
            url: tokenUrl,
          );
        },
      ).toList(),
      visibility: _mapVisibility(_visibility),
      commentPermission: _mapCommentPermission(_commentControl),
    );
    _bloc.add(
      HomeEvent.createFeedPost(
        request: request,
        localMediaPayloads: localMediaPayloads,
      ),
    );
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
                onPressed: canSubmit
                    ? () => _submit(viewModel.postComposerPhotos)
                    : null,
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
                            _ComposerMediaPreview(
                              bytes: photo.bytes,
                              fileName: photo.fileName,
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
                      'Media',
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

bool _isVideoFileName(String fileName) {
  final value = fileName.toLowerCase();
  return value.endsWith('.mp4') ||
      value.endsWith('.mov') ||
      value.endsWith('.m4v') ||
      value.endsWith('.avi') ||
      value.endsWith('.mkv') ||
      value.endsWith('.webm');
}

class _ComposerMediaPreview extends StatelessWidget {
  const _ComposerMediaPreview({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final isVideo = _isVideoFileName(fileName);
    if (!isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 95,
          height: 95,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 95,
      height: 95,
      decoration: BoxDecoration(
        color: AppColors.colorff2A2A2B,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.colorff3F3F40),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
          Gap(4),
          Text(
            'Video',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

