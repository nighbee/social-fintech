import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'context_activity_bloc.freezed.dart';
part 'context_activity_event.dart';
part 'context_activity_state.dart';

class ContextActivityBloc
    extends Bloc<ContextActivityEvent, ContextActivityState> {
  ContextActivityBloc()
      : super(const ContextActivityState.handleActionWithContext(null)) {
    on<HandleContextActivityEvent>(
      (HandleContextActivityEvent event, Emitter<ContextActivityState> emit) =>
          emit(ContextActivityState.handleActionWithContext(event.callback)),
    );
  }
}
