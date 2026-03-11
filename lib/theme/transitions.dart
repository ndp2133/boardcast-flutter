// Custom transitions — page routes and scroll physics for premium feel.
import 'package:flutter/material.dart';

/// Slide-up + fade page route for modal-style screen transitions.
class SlideUpRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  SlideUpRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      ),
    );
  }
}

/// Tighter bounce physics — lighter mass + stiffer spring for snappy feel.
class BoardcastScrollPhysics extends BouncingScrollPhysics {
  const BoardcastScrollPhysics({super.parent});

  @override
  BoardcastScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BoardcastScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
        mass: 0.4,
        stiffness: 110.0,
        ratio: 1.05,
      );
}

/// Scroll behavior that applies custom physics across all platforms.
class BoardcastScrollBehavior extends ScrollBehavior {
  const BoardcastScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BoardcastScrollPhysics();
  }
}
