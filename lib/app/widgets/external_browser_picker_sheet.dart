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

class _BrowserPickerScrollableContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showListHint) ...[
          _BrowserPickerListHint(l10n: l10n),
          const SizedBox(height: 12),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: _BrowserPickerBody(
            browsers: browsers,
            selectedChoice: selectedChoice,
            onSelected: onSelected,
          ),
        ),
      ],
    );
  }
}

class _BrowserPickerBody extends StatelessWidget {
  const _BrowserPickerBody({
    required this.browsers,
    required this.selectedChoice,
    required this.onSelected,
  });

  final List<HttpsBrowserInfo> browsers;
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
          selected: selectedChoice == externalBrowserChoiceSystem,
          onTap: () => onSelected(externalBrowserChoiceSystem),
        ),
        ...browsers.map(
          (browser) => _BrowserChoiceTile(
            title: browser.label,
            subtitle: browser.packageName,
            selected: selectedChoice == browser.packageName,
            onTap: () => onSelected(browser.packageName),
          ),
        ),
      ],
    );
  }
}

class _BrowserChoiceTile extends StatelessWidget {
  const _BrowserChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
