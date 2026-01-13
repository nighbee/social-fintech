import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';

import '../context/context_activity_bloc.dart';
import 'base_cubit.dart';

typedef BaseCubitWidgetBuilder<C, S> = Widget Function(
  BuildContext context,
  S state,
  C cubit,
);

class BaseCubitWidget<C extends BaseCubit<S>, S> extends StatelessWidget {
  BaseCubitWidget({
    required this.cubit,
    required this.builder,
    this.listener,
    this.buildWhen,
    super.key,
  });

  final C cubit;
  final BaseCubitWidgetBuilder<C, S> builder;
  final BlocWidgetListener<S>? listener;
  final BlocBuilderCondition<S>? buildWhen;

  final ContextActivityBloc contextActivity = ContextActivityBloc();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider(
          create: (BuildContext context) => contextActivity,
        ),
        BlocProvider(
          create: (BuildContext context) =>
              cubit..withContextHandler(contextActivity),
        ),
      ],
      child: BlocListener<ContextActivityBloc, ContextActivityState>(
        listener: (BuildContext context, ContextActivityState state) =>
            state.contextActivityHandler != null
                ? state.contextActivityHandler!(context)
                : null,
        child: BlocConsumer<C, S>(
          listener: listener ?? (BuildContext context, s) {},
          builder: (BuildContext context, s) =>
              builder(context, s, context.read<C>()),
          buildWhen: buildWhen,
        ),
      ),
    );
  }
}
