import 'dart:async';

import 'package:flutter/material.dart';

enum AppToastAnimation { fade, slide }

enum AppToastLocation { top, bottom }

class AppToast extends StatelessWidget {
  const AppToast({
    required this.message,
    required this.location,
    required this.edgeDistance,
    super.key,
  });

  final String message;
  final AppToastLocation location;
  final double edgeDistance;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: location == AppToastLocation.top
              ? Alignment.topCenter
              : Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              24,
              location == AppToastLocation.top ? edgeDistance : 0,
              24,
              location == AppToastLocation.bottom ? edgeDistance : 0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.35,
                  ),
              textAlign: TextAlign.center,
              child: Text(message),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedAppToast extends StatefulWidget {
  const _AnimatedAppToast({
    required this.message,
    required this.animation,
    required this.location,
    required this.edgeDistance,
    required this.duration,
    required this.onDismissed,
    super.key,
  });

  final String message;
  final AppToastAnimation animation;
  final AppToastLocation location;
  final double edgeDistance;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedAppToast> createState() => _AnimatedAppToastState();
}

class _AnimatedAppToastState extends State<_AnimatedAppToast>
    with SingleTickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 220);
  static const _exitDuration = Duration(milliseconds: 180);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _enterDuration,
    reverseDuration: _exitDuration,
  );
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: widget.location == AppToastLocation.top
        ? const Offset(0, -0.14)
        : const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
  );

  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(widget.duration, dismiss);
  }

  Future<void> dismiss({bool immediately = false}) async {
    if (_isDismissing) {
      return;
    }

    _isDismissing = true;
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (!immediately) {
      await _controller.reverse();
    }

    widget.onDismissed();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toast = AppToast(
      message: widget.message,
      location: widget.location,
      edgeDistance: widget.edgeDistance,
    );

    switch (widget.animation) {
      case AppToastAnimation.fade:
        return FadeTransition(
          opacity: _fadeAnimation,
          child: toast,
        );
      case AppToastAnimation.slide:
        return SlideTransition(
        position: _slideAnimation,
          child: toast,
        );
    }
  }
}

class AppToastController {
  static OverlayEntry? _currentEntry;
  static GlobalKey<_AnimatedAppToastState>? _currentToastKey;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    AppToastAnimation animation = AppToastAnimation.fade,
    AppToastLocation location = AppToastLocation.bottom,
    double edgeDistance = 40,
  }) {
    _dismissCurrent(immediately: true);

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    final toastKey = GlobalKey<_AnimatedAppToastState>();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AnimatedAppToast(
        key: toastKey,
        message: message,
        animation: animation,
        location: location,
        edgeDistance: edgeDistance,
        duration: duration,
        onDismissed: () {
          if (identical(_currentEntry, entry)) {
            _removeCurrentToast();
          }
        },
      ),
    );
    _currentEntry = entry;
    _currentToastKey = toastKey;
    overlay.insert(entry);
  }

  static void _dismissCurrent({bool immediately = false}) {
    final currentState = _currentToastKey?.currentState;
    if (currentState != null) {
      currentState.dismiss(immediately: immediately);
      return;
    }

    _removeCurrentToast();
  }

  static void _removeCurrentToast() {
    _currentEntry?.remove();
    _currentEntry = null;
    _currentToastKey = null;
  }

  static void dismiss() {
    _dismissCurrent();
  }
}

void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  AppToastAnimation animation = AppToastAnimation.fade,
  AppToastLocation location = AppToastLocation.bottom,
  double edgeDistance = 40,
}) {
  AppToastController.show(
    context,
    message,
    duration: duration,
    animation: animation,
    location: location,
    edgeDistance: edgeDistance,
  );
}



