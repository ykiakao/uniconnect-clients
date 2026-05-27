import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouteTransitionPage<T> extends CustomTransitionPage<T> {
  const AppRouteTransitionPage.slideFromRight({
    required LocalKey super.key,
    required super.child,
  }) : super(
          transitionDuration: _duration,
          reverseTransitionDuration: _reverseDuration,
          transitionsBuilder: _buildSlideFromRightTransition,
        );

  const AppRouteTransitionPage.slideFromBottom({
    required LocalKey super.key,
    required super.child,
  }) : super(
          transitionDuration: _duration,
          reverseTransitionDuration: _reverseDuration,
          transitionsBuilder: _buildSlideFromBottomTransition,
        );

  const AppRouteTransitionPage.fade({
    required LocalKey super.key,
    required super.child,
  }) : super(
          transitionDuration: _duration,
          reverseTransitionDuration: _reverseDuration,
          transitionsBuilder: _buildFadeTransition,
        );

  static const _duration = Duration(milliseconds: 260);
  static const _reverseDuration = Duration(milliseconds: 190);

  static Widget _buildSlideFromRightTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeSlideTransition(
      animation: animation,
      begin: const Offset(.08, 0),
      child: child,
    );
  }

  static Widget _buildSlideFromBottomTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeSlideTransition(
      animation: animation,
      begin: const Offset(0, .08),
      child: child,
    );
  }

  static Widget _buildFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeAnimation = animation.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );

    return FadeTransition(opacity: fadeAnimation, child: child);
  }
}

class _FadeSlideTransition extends StatelessWidget {
  const _FadeSlideTransition({
    required this.animation,
    required this.begin,
    required this.child,
  });

  final Animation<double> animation;
  final Offset begin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curvedAnimation = animation.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );
    final offsetAnimation = animation.drive(
      Tween<Offset>(begin: begin, end: Offset.zero).chain(
        CurveTween(curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(position: offsetAnimation, child: child),
    );
  }
}
