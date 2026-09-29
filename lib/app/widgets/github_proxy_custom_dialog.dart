import 'package:bilirec/app/widgets/settings/settings_hint.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/github_api_base.dart';
import 'package:bilirec/shared/github_api_probe.dart';
import 'package:bilirec/shared/github_api_proxy_presets.dart';
import 'package:flutter/material.dart';

enum _FieldCheckPhase { idle, checking, success, error }

/// Returns saved [GitHubProxySettings] on success, or `null` if cancelled.
Future<GitHubProxySettings?> showGitHubProxyCustomDialog(
  BuildContext context, {
  required GitHubProxySettings initial,
  required String docsUrl,
}) {
  return showDialog<GitHubProxySettings>(
    context: context,
    barrierDismissible: false,
    builder: (context) => GitHubProxyCustomDialog(
      initial: initial,
      docsUrl: docsUrl,
    ),
  );
}

class GitHubProxyCustomDialog extends StatefulWidget {
  const GitHubProxyCustomDialog({
    required this.initial,
    required this.docsUrl,
    super.key,
  });

  final GitHubProxySettings initial;
  final String docsUrl;

  @override
  State<GitHubProxyCustomDialog> createState() =>
      _GitHubProxyCustomDialogState();
}

class _GitHubProxyCustomDialogState extends State<GitHubProxyCustomDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _apiController;
  late final TextEditingController _githubController;

  bool _submitting = false;
  _FieldCheckPhase _apiPhase = _FieldCheckPhase.idle;
  _FieldCheckPhase _githubPhase = _FieldCheckPhase.idle;
  String? _apiError;
  String? _githubError;
  bool _buttonCheckActive = false;

  late final AnimationController _buttonCheckController;
  late final Animation<double> _buttonCheckScale;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: widget.initial.apiBaseUrl);
    _githubController = TextEditingController(text: widget.initial.githubBaseUrl);
    _buttonCheckController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _buttonCheckScale = CurvedAnimation(
      parent: _buttonCheckController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _buttonCheckController.dispose();
    _apiController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  Future<void> _finishWithButtonCheck(GitHubProxySettings settings) async {
    _buttonCheckController.reset();
    if (mounted) {
      setState(() => _buttonCheckActive = true);
    }
    await _buttonCheckController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(settings);
  }

  bool get _inputsEnabled => !_submitting;

  Future<void> _onSubmit() async {
    final apiRaw = _apiController.text;
    final githubRaw = _githubController.text;
    final apiBase = normalizeGitHubApiBaseUrl(apiRaw);
    final githubBase = normalizeGitHubBaseUrl(githubRaw);

    setState(() {
      _submitting = true;
      _buttonCheckActive = false;
      _apiPhase = _FieldCheckPhase.idle;
      _githubPhase = _FieldCheckPhase.idle;
      _apiError = null;
      _githubError = null;
    });
    _buttonCheckController.reset();

    if (apiBase.isEmpty) {
      setState(() {
        _submitting = false;
        _apiPhase = _FieldCheckPhase.error;
        _apiError = l10n.tr('githubApiProxyCustomApiRequired');
      });
      return;
    }

    setState(() => _apiPhase = _FieldCheckPhase.checking);
    final releaseProbe = await fetchGitHubLatestRelease(apiBase: apiBase);
    if (!mounted) {
      return;
    }

    if (!releaseProbe.reachable) {
      setState(() {
        _submitting = false;
        _apiPhase = _FieldCheckPhase.error;
        _apiError = l10n.tr('githubApiProxyCustomUnreachable');
      });
      return;
    }

    setState(() => _apiPhase = _FieldCheckPhase.success);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) {
      return;
    }

    if (isOfficialGitHubWebBase(githubBase)) {
      setState(() => _githubPhase = _FieldCheckPhase.success);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) {
        return;
      }
      await _finishWithButtonCheck(
        GitHubProxySettings(
          apiBaseUrl: apiBase,
          githubBaseUrl: githubBase,
        ),
      );
      return;
    }

    final release = releaseProbe.release;
    final downloadUrl =
        release != null ? webBrowserDownloadUrlFromRelease(release) : null;
    if (downloadUrl == null) {
      setState(() {
        _submitting = false;
        _githubPhase = _FieldCheckPhase.error;
        _githubError = l10n.tr('githubApiProxyCustomGithubNoAsset');
      });
      return;
    }

    setState(() => _githubPhase = _FieldCheckPhase.checking);
    final webOk = await probeGitHubWebDownloadUrl(
      githubBase: githubBase,
      officialDownloadUrl: downloadUrl,
    );
    if (!mounted) {
      return;
    }

    if (!webOk) {
      setState(() {
        _submitting = false;
        _githubPhase = _FieldCheckPhase.error;
        _githubError = l10n.tr('githubApiProxyCustomGithubUnreachable');
      });
      return;
    }

    setState(() => _githubPhase = _FieldCheckPhase.success);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) {
      return;
    }

    await _finishWithButtonCheck(
      GitHubProxySettings(
        apiBaseUrl: apiBase,
        githubBaseUrl: githubBase,
      ),
    );
  }

  Widget? _suffixForPhase(_FieldCheckPhase phase) {
    switch (phase) {
      case _FieldCheckPhase.idle:
        return null;
      case _FieldCheckPhase.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _FieldCheckPhase.success:
        return Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
        );
      case _FieldCheckPhase.error:
        return Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }

  InputDecoration _urlFieldDecoration({
    required String labelText,
    required _FieldCheckPhase phase,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      border: const OutlineInputBorder(),
      errorText: errorText,
      errorMaxLines: 4,
      suffixIcon: _suffixForPhase(phase),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width - 32).clamp(320.0, 520.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      scrollable: true,
      title: Text(l10n.tr('githubApiProxyCustomDialogTitle')),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('github_proxy_custom_api_field'),
              controller: _apiController,
              enabled: _inputsEnabled,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              style: theme.textTheme.bodyMedium,
              decoration: _urlFieldDecoration(
                labelText: l10n.tr('githubApiProxyCustomApiLabel'),
                phase: _apiPhase,
                errorText: _apiError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('github_proxy_custom_github_field'),
              controller: _githubController,
              enabled: _inputsEnabled,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              style: theme.textTheme.bodyMedium,
              decoration: _urlFieldDecoration(
                labelText: l10n.tr('githubApiProxyCustomGithubLabel'),
                phase: _githubPhase,
                errorText: _githubError,
              ),
            ),
            const SizedBox(height: 12),
            SettingsHint(
              text: l10n.tr('githubApiProxyHint'),
              inlineLinkLabel: l10n.tr('githubApiProxyHintLink'),
              onInlineLinkTap: () {
                openUrlPreferChrome(Uri.parse(widget.docsUrl));
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _onSubmit,
          child: _buttonCheckActive
              ? ScaleTransition(
                  scale: _buttonCheckScale,
                  child: Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : _submitting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text(l10n.tr('githubApiProxyCustomSave')),
        ),
      ],
    );
  }
}
