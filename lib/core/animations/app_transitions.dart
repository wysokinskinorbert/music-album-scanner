import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../theme/app_colors.dart';

/// Custom page transitions for a polished UX.
class AppTransitions {
  // ==========================================
  // Shared Axis Transitions (Material Motion)
  // ==========================================

  /// Horizontal shared axis - for forward/backward navigation.
  /// Use between: scan -> result, collection -> detail.
  static Route<T> sharedAxisHorizontal<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: AppColors.background,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  /// Vertical shared axis - for drill-down into detail.
  static Route<T> sharedAxisVertical<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.vertical,
          fillColor: AppColors.background,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  /// Scaled shared axis - for opening modals/details.
  static Route<T> sharedAxisScaled<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.scaled,
          fillColor: AppColors.background,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ==========================================
  // Fade Through (tab-like transitions)
  // ==========================================

  /// Fade through - for bottom nav tab changes.
  static Route<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: AppColors.background,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // ==========================================
  // Container Transform (hero-like)
  // ==========================================

  /// Container transform - for album card -> detail.
  static Widget containerTransform({
    required Key key,
    required bool isOpen,
    required Widget closedChild,
    required Widget openChild,
    required ShapeBorder closedShape,
    required ShapeBorder openShape,
    double closedElevation = 0,
    double openElevation = 0,
    Color? closedColor,
    Color? openColor,
  }) {
    return OpenContainer(
      key: key,
      closedBuilder: (context, action) => closedChild,
      openBuilder: (context, action) => openChild,
      closedShape: closedShape,
      openShape: openShape,
      closedElevation: closedElevation,
      openElevation: openElevation,
      closedColor: closedColor ?? AppColors.surface,
      openColor: openColor ?? AppColors.background,
      transitionDuration: const Duration(milliseconds: 500),
      transitionType: ContainerTransitionType.fade,
    );
  }

  // ==========================================
  // Convenience Navigation Methods
  // ==========================================

  /// Navigate with horizontal shared axis.
  static Future<T?> pushHorizontal<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push(sharedAxisHorizontal<T>(page));
  }

  /// Navigate with vertical shared axis.
  static Future<T?> pushVertical<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push(sharedAxisVertical<T>(page));
  }

  /// Navigate with scaled shared axis.
  static Future<T?> pushScaled<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push(sharedAxisScaled<T>(page));
  }
}

// ==========================================
// Animated Widgets
// ==========================================

/// Fade-in widget for staggered list animations.
class FadeInWidget extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;

  const FadeInWidget({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Slide-up widget for bottom sheets and cards.
class SlideUpWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double beginOffset;

  const SlideUpWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.beginOffset = 0.1,
  });

  @override
  State<SlideUpWidget> createState() => _SlideUpWidgetState();
}

class _SlideUpWidgetState extends State<SlideUpWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.beginOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// Scale-in widget for FABs and badges.
class ScaleInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ScaleInWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<ScaleInWidget> createState() => _ScaleInWidgetState();
}

class _ScaleInWidgetState extends State<ScaleInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
