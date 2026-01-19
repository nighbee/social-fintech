part of 'context_activity_bloc.dart';

typedef ContextActivityCallback = void Function(BuildContext context);

@freezed
class ContextActivityState with _$ContextActivityState {
  const ContextActivityState._();

  const factory ContextActivityState.handleActionWithContext(
          ContextActivityCallback? contextActivityHandler) =
      HandleActionWithContext;
}
