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
class HomeViewModel with _$HomeViewModel {
  const HomeViewModel._();
  factory HomeViewModel({@Default([]) List<PostEntity> posts}) = _HomeViewModel;
}
