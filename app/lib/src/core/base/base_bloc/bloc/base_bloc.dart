import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../utils/loggers/log.dart';
import '../context/context_activity_bloc.dart';

abstract class BaseBloc<E, S> extends Bloc<E, S> {
  BaseBloc(super.initialState) {
    on<E>(onEventHandler);
  }
  ContextActivityBloc? contextActivity;

  void onEventHandler(E event, Emitter emit);

  void withContextHandler(ContextActivityBloc contextActivityBloc) {
    contextActivity = contextActivityBloc;
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    Log.e('BlocError: ${error.toString()}');
    super.onError(error, stackTrace);
  }
}
