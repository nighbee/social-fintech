part of 'profile_bloc.dart';

@freezed
class ProfileEvent with _$ProfileEvent {
  const factory ProfileEvent.loadProfile() = _LoadProfile;
  const factory ProfileEvent.loadPublicProfile(String userId) =
      _LoadPublicProfile;
  const factory ProfileEvent.becomeAlly(String userId) = _BecomeAlly;
  const factory ProfileEvent.removeAlly(String userId) = _RemoveAlly;
  const factory ProfileEvent.loadAllies(String userId) = _LoadAllies;
  const factory ProfileEvent.loadCurrentUserAllies() = _LoadCurrentUserAllies;
  const factory ProfileEvent.blockUser(String userId) = _BlockUser;
  const factory ProfileEvent.unblockUser(String userId) = _UnblockUser;
  const factory ProfileEvent.restrictUser(String userId) = _RestrictUser;
  const factory ProfileEvent.unrestrictUser(String userId) = _UnrestrictUser;
  const factory ProfileEvent.reportUser(String userId) = _ReportUser;
  const factory ProfileEvent.loadRelationship(String userId) =
      _LoadRelationship;
  const factory ProfileEvent.updateProfile(UpdateProfileRequest request) =
      _UpdateProfile;
  const factory ProfileEvent.logout() = _Logout;
}
