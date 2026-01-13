import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../context/context_activity_bloc.dart';
import 'base_bloc.dart';

typedef BaseBlocWidgetBuilder<B, S> = Widget Function(
  BuildContext context,
  S state,
  B bloc,
);

class BaseBlocWidget<B extends BaseBloc<E, S>, E, S> extends StatelessWidget {
  BaseBlocWidget({
    required this.bloc,
    required this.builder,
    this.starterEvent,
    this.listener,
    this.buildWhen,
    this.listenWhen,
    super.key,
  });

  final B bloc;
  final E? starterEvent;
  final BaseBlocWidgetBuilder<B, S> builder;
  final BlocWidgetListener<S>? listener;
  final BlocBuilderCondition<S>? buildWhen;
  final BlocBuilderCondition<S>? listenWhen;

  final ContextActivityBloc contextActivity = ContextActivityBloc();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider(
          create: (BuildContext context) => contextActivity,
        ),
        BlocProvider(
          create: (BuildContext context) {
            if (starterEvent != null) {
              return bloc
                ..withContextHandler(contextActivity)
                ..add(starterEvent as E);
            }
            return bloc..withContextHandler(contextActivity);
          },
        ),
      ],
      child: BlocListener<ContextActivityBloc, ContextActivityState>(
        listener: (BuildContext context, ContextActivityState state) =>
            state.contextActivityHandler != null
                ? state.contextActivityHandler!(context)
                : null,
        child: BlocConsumer<B, S>(
          listener: listener ?? (BuildContext context, s) {},
          builder: (BuildContext context, s) =>
              builder(context, s, context.read<B>()),
          buildWhen: buildWhen,
          listenWhen: listenWhen,
        ),
      ),
    );
  }
}
