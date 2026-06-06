import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ServicePowerButtonArea extends StatefulWidget {
  const ServicePowerButtonArea({
    required this.size,
    required this.actionInFlight,
    required this.isServiceRunning,
    required this.isStarting,
    required this.isStopping,
    required this.buttonGradientColors,
    required this.onTap,
    super.key,
  });

  final Size size;
  final bool actionInFlight;
  final bool isServiceRunning;
  final bool isStarting;
  final bool isStopping;
  final List<Color> buttonGradientColors;
  final VoidCallback onTap;

  @override
  State<ServicePowerButtonArea> createState() => _ServicePowerButtonAreaState();
}

class _ServicePowerButtonAreaState extends State<ServicePowerButtonArea>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _localPulseScale;
  Animation<double>? _localPulseOpacity;
  Animation<double>? _localStopScale;
  Animation<double>? _localStopOpacity;

  bool get _shouldPulse => widget.isStarting || widget.isStopping;

  @override
  void initState() {
    super.initState();
    _ensurePulseAnimation();
    _syncPulseAnimation();
  }

  @override
  void didUpdateWidget(covariant ServicePowerButtonArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensurePulseAnimation();
    _syncPulseAnimation();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _ensurePulseAnimation() {
    if (_pulseController != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curved =
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    _pulseController = controller;
    _localPulseScale = Tween<double>(begin: 0.82, end: 1.16).animate(curved);
    _localPulseOpacity = Tween<double>(begin: 0.72, end: 1.0).animate(curved);

    // Stopping animation: shrink and fade out
    _localStopScale = Tween<double>(begin: 1.0, end: 0.7).animate(curved);
    _localStopOpacity = Tween<double>(begin: 1.0, end: 0.5).animate(curved);
  }

  void _syncPulseAnimation() {
    final controller = _pulseController;
    if (controller == null) return;

    if (_shouldPulse) {
      if (!controller.isAnimating) {
        controller.repeat(reverse: true);
      }
    } else if (controller.isAnimating) {
      controller.stop();
    }
  }

  String _buildLabel(AppLocalizations l10n) {
    if (widget.actionInFlight) {
      return widget.isStopping
          ? l10n.tr('stoppingShort')
          : l10n.tr('startingShort');
    }
    return widget.isServiceRunning ? l10n.tr('stop') : l10n.tr('start');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final buttonSide =
        (widget.size.shortestSide * 0.32).clamp(96.0, 144.0).toDouble();
    final buttonRadius = buttonSide * 0.25;
    final iconBoxSide = (buttonSide * 0.34).clamp(32.0, 48.0).toDouble();
    final iconSize = (iconBoxSide * 0.9).clamp(26.0, 44.0).toDouble();
    final labelSpacing = (buttonSide * 0.05).clamp(4.0, 8.0).toDouble();
    final labelFontSize = (buttonSide * 0.14).clamp(12.0, 18.0).toDouble();

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -64),
          child: SizedBox(
            width: buttonSide,
            height: buttonSide,
            child: GestureDetector(
              onTap: widget.actionInFlight ? null : widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.buttonGradientColors,
                  ),
                  borderRadius: BorderRadius.circular(buttonRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5BAEDB).withValues(alpha: 0.55),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    if (widget.actionInFlight)
                      BoxShadow(
                        color: const Color(0xFFB9E9FF).withValues(alpha: 0.7),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Column(
                      key: UniqueKey(),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: iconBoxSide,
                          height: iconBoxSide,
                          child: Center(
                            child: widget.isStarting
                                ? FadeTransition(
                                    opacity: _localPulseOpacity ??
                                        const AlwaysStoppedAnimation<double>(
                                            1.0),
                                    child: ScaleTransition(
                                      scale: _localPulseScale ??
                                          const AlwaysStoppedAnimation<double>(
                                            1.0,
                                          ),
                                      child: Icon(
                                        Icons.power_settings_new,
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : widget.isStopping
                                    ? FadeTransition(
                                        opacity: _localStopOpacity ??
                                            const AlwaysStoppedAnimation<
                                                double>(1.0),
                                        child: ScaleTransition(
                                          scale: _localStopScale ??
                                              const AlwaysStoppedAnimation<
                                                  double>(
                                                1.0,
                                              ),
                                          child: Icon(
                                            Icons.power_settings_new,
                                            size: iconSize,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.power_settings_new,
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                          ),
                        ),
                        SizedBox(height: labelSpacing),
                        Text(
                          _buildLabel(l10n),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: labelFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
