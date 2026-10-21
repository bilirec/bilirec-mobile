import 'dart:typed_data';

import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/browser_packages.dart';
import 'package:flutter/material.dart';

class ExternalBrowserPickerResult {
  const ExternalBrowserPickerResult({
    required this.choice,
    required this.remember,
  });

  final String choice;
  final bool remember;
}

Future<ExternalBrowserPickerResult?> showExternalBrowserPickerSheet(
  BuildContext context, {
  String? currentChoice,
  bool promptToRemember = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final browsers = await listHttpsBrowsers();
  if (!context.mounted) {
    return null;
  }

  if (!promptToRemember) {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.tr('externalBrowserPickerTitle')),
          content: SizedBox(
            width: double.maxFinite,
            child: _BrowserPickerScrollableContent(
              l10n: l10n,
              browsers: browsers,
              selectedChoice: currentChoice,
              showListHint: true,
              onSelected: (choice) => Navigator.of(dialogContext).pop(choice),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.tr('unexpectedStopDismiss')),
            ),
          ],
        );
      },
    );
    if (choice == null) {
      return null;
    }
    return ExternalBrowserPickerResult(choice: choice, remember: true);
  }

  return showDialog<ExternalBrowserPickerResult>(
    context: context,
    builder: (dialogContext) {
      var selectedChoice = currentChoice ?? externalBrowserChoiceSystem;
      var rememberChoice = true;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.tr('externalBrowserPickerTitle')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrowserPickerScrollableContent(
                    l10n: l10n,
                    browsers: browsers,
                    selectedChoice: selectedChoice,
                    showListHint: true,
                    onSelected: (choice) {
                      setState(() => selectedChoice = choice);
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l10n.tr('externalBrowserRememberChoice')),
                    value: rememberChoice,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => rememberChoice = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.tr('unexpectedStopDismiss')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(
                  ExternalBrowserPickerResult(
                    choice: selectedChoice,
                    remember: rememberChoice,
                  ),
                ),
                child: Text(l10n.tr('externalBrowserPickerConfirm')),
              ),
            ],
          );
        },
      );
    },
  );
}

class _BrowserPickerListHint extends StatelessWidget {
  const _BrowserPickerListHint({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SettingsHint(text: l10n.tr('externalBrowserListHint'));
  }
}

class _BrowserPickerScrollableContent extends StatefulWidget {
  const _BrowserPickerScrollableContent({
    required this.l10n,
    required this.browsers,
    required this.selectedChoice,
    required this.showListHint,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final List<HttpsBrowserInfo> browsers;
  final String? selectedChoice;
  final bool showListHint;
  final ValueChanged<String> onSelected;

  @override
  State<_BrowserPickerScrollableContent> createState() =>
      _BrowserPickerScrollableContentState();
}

class _BrowserPickerScrollableContentState
    extends State<_BrowserPickerScrollableContent> {
  Map<String, Uint8List> _iconsByPackage = const {};
  bool _iconsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  @override
  void didUpdateWidget(covariant _BrowserPickerScrollableContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameBrowserPackages(oldWidget.browsers, widget.browsers)) {
      _loadIcons();
    }
  }

  bool _sameBrowserPackages(
    List<HttpsBrowserInfo> a,
    List<HttpsBrowserInfo> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].packageName != b[i].packageName) return false;
    }
    return true;
  }

  Future<void> _loadIcons() async {
    final packageNames =
        widget.browsers.map((browser) => browser.packageName).toList();
    if (packageNames.isEmpty) {
      if (!mounted) return;
      setState(() {
        _iconsByPackage = const {};
        _iconsLoading = false;
      });
      return;
    }

    setState(() => _iconsLoading = true);
    final icons = await loadHttpsBrowserIcons(packageNames);
    if (!mounted) return;
    setState(() {
      _iconsByPackage = icons;
      _iconsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showListHint) ...[
          _BrowserPickerListHint(l10n: widget.l10n),
          const SizedBox(height: 12),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _BrowserPickerBody(
            browsers: widget.browsers,
            iconsByPackage: _iconsByPackage,
            iconsLoading: _iconsLoading,
            selectedChoice: widget.selectedChoice,
            onSelected: widget.onSelected,
          ),
        ),
      ],
    );
  }
}

class _BrowserPickerBody extends StatelessWidget {
  const _BrowserPickerBody({
    required this.browsers,
    required this.iconsByPackage,
    required this.iconsLoading,
    required this.selectedChoice,
    required this.onSelected,
  });

  final List<HttpsBrowserInfo> browsers;
  final Map<String, Uint8List> iconsByPackage;
  final bool iconsLoading;
  final String? selectedChoice;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        _BrowserChoiceTile(
          title: l10n.tr('externalBrowserSystemDefault'),
          leading: const _BrowserLeadingIcon.systemDefault(),
          selected: selectedChoice == externalBrowserChoiceSystem,
          onTap: () => onSelected(externalBrowserChoiceSystem),
        ),
        ...browsers.map(
          (browser) => _BrowserChoiceTile(
            title: browser.label,
            subtitle: browser.packageName,
            leading: _BrowserLeadingIcon.packageIcon(
              png: iconsByPackage[browser.packageName],
              loading: iconsLoading,
            ),
            selected: selectedChoice == browser.packageName,
            onTap: () => onSelected(browser.packageName),
          ),
        ),
      ],
    );
  }
}

class _BrowserLeadingIcon extends StatelessWidget {
  const _BrowserLeadingIcon._({required this.child});

  const _BrowserLeadingIcon.systemDefault() : this._(child: const Icon(Icons.language));

  _BrowserLeadingIcon.packageIcon({
    required Uint8List? png,
    required bool loading,
  }) : this._(
          child: png != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    png,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                )
              : loading
                  ? const _BrowserIconSkeleton()
                  : const Icon(Icons.public),
        );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(child: child),
    );
  }
}

class _BrowserIconSkeleton extends StatefulWidget {
  const _BrowserIconSkeleton();

  @override
  State<_BrowserIconSkeleton> createState() => _BrowserIconSkeletonState();
}

class _BrowserIconSkeletonState extends State<_BrowserIconSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
                end: Alignment(2.0 * _controller.value, 0),
                colors: [
                  colorScheme.surfaceContainerHighest,
                  colorScheme.surfaceContainerHigh,
                  colorScheme.surfaceContainerHighest,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrowserChoiceTile extends StatelessWidget {
  const _BrowserChoiceTile({
    required this.title,
    required this.leading,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final Widget leading;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
