part of 'home_bloc.dart';

@freezed
class HomeState with _$HomeState {
  const factory HomeState.initial() = _Initial;
  const factory HomeState.loading({required HomeViewModel viewModel}) =
      _Loading;
  const factory HomeState.loadingError(String message) = _LoadingError;
  const factory HomeState.loaded({required HomeViewModel viewModel}) = _Loaded;
}

@freezed
class CommentComposerPhoto with _$CommentComposerPhoto {
  const factory CommentComposerPhoto({
    required Uint8List bytes,
    required String fileName,
  }) = _CommentComposerPhoto;
}

@freezed
class HomeViewModel with _$HomeViewModel {
  const HomeViewModel._();
  factory HomeViewModel({
    @Default(FeedEntity.empty()) FeedEntity feed,
    @Default(ThreadedCommentsEntity.empty()) ThreadedCommentsEntity comments,
    @Default(InteractionListEntity.empty()) InteractionListEntity likes,
    @Default(StatusResponseEntity.empty()) StatusResponseEntity lastAction,
    @Default(StoreSummaryEntity.empty()) StoreSummaryEntity storeSummary,
    @Default(ClaimDailyAccrualResultEntity.empty())
    ClaimDailyAccrualResultEntity lastStoreAccrualResult,
    @Default(<LocalMediaPayload>[]) List<LocalMediaPayload> localMediaPayloads,
    @Default([]) List<CommentComposerPhoto> postComposerPhotos,
    @Default([]) List<NotificationEntity> notifications,
    @Default(FeedStateEntity.empty()) FeedStateEntity feedState,
  }) = _HomeViewModel;

  HomeViewModel addPostComposerPhoto(CommentComposerPhoto photo) {
    if (postComposerPhotos.any((item) => item.fileName == photo.fileName)) {
      return this;
    }
    return copyWith(postComposerPhotos: [...postComposerPhotos, photo]);
  }

  HomeViewModel removePostComposerPhoto(String fileName) {
    return copyWith(
      postComposerPhotos: postComposerPhotos
          .where((photo) => photo.fileName != fileName)
          .toList(),
    );
  }
}

