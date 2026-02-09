part of 'profile_bloc.dart';

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState.initial() = _Initial;
  const factory ProfileState.loading({required ProfileViewModel viewModel}) =
      _Loading;
  const factory ProfileState.loadingError(String message) = _LoadingError;
  const factory ProfileState.loaded({required ProfileViewModel viewModel}) =
      _Loaded;
}

@freezed
class ProfileViewModel with _$ProfileViewModel {
  const ProfileViewModel._();
  factory ProfileViewModel({
    @Default(ProfileEntity.empty()) ProfileEntity profile,
  }) = _ProfileViewModel;
}
