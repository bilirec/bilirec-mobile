import 'package:bilirec/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ServiceActionSection extends StatelessWidget {
  const ServiceActionSection({
    required this.visible,
    required this.onOpenFrontend,
    required this.onCheckBackendConnection,
    super.key,
  });

  final bool visible;
  final VoidCallback onOpenFrontend;
  final VoidCallback onCheckBackendConnection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.fastOutSlowIn,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: visible
            ? Column(
                key: const ValueKey('service-actions-visible'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenFrontend,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.tr('openFrontend')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onCheckBackendConnection,
                    icon: const Icon(Icons.lan, size: 16),
                    label: Text(l10n.tr('checkBackendConnection')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5BAEDB),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              )
            : const SizedBox(
                key: ValueKey('service-actions-hidden'),
                height: 0,
              ),
      ),
    );
  }
}
