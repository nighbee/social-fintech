part of 'router.dart';

class PageTransitions {
  static CustomTransitionPage defaultTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  static CustomTransitionPage fade<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    required double begin,
    required double end,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          FadeTransition(
        opacity: Tween<double>(begin: begin, end: end).animate(animation),
        child: child,
      ),
    );
  }

  static CustomTransitionPage slide<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    required Offset begin,
    required Offset end,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          SlideTransition(
        position: Tween<Offset>(begin: begin, end: end).animate(animation),
        child: child,
      ),
    );
  }

  static CustomTransitionPage scale<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    required double begin,
    required double end,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          ScaleTransition(
        scale: Tween<double>(begin: begin, end: end).animate(animation),
        child: child,
      ),
    );
  }

  static CustomTransitionPage slideAndFade<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    required Offset begin,
    required Offset end,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation, Widget child) =>
          FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: begin, end: end).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

