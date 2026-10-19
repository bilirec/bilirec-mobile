import 'dart:async';
import 'dart:io';

import 'package:bilirec/app/home/app_update_prompt.dart';
import 'package:bilirec/app/home/service_session.dart';
import 'package:bilirec/app/home/service_toggle.dart';
import 'package:bilirec/app/widgets/home_page_language_menu.dart';
import 'package:bilirec/app/widgets/service_action_section.dart';
import 'package:bilirec/app/widgets/service_power_button_area.dart';
import 'package:bilirec/app/widgets/service_status_row.dart';
import 'package:bilirec/app/widgets/settings_card.dart';
import 'package:bilirec/app/widgets/unexpected_stop_dialog.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/app_update_service.dart';
import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/device_uptime.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/unexpected_stop.dart';
import 'package:bilirec/shared/unexpected_stop_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

export 'package:bilirec/app/home/service_toggle.dart' show startCallback;

class BilirecHomePage extends StatefulWidget {
  const BilirecHomePage({
    required this.currentLocale,
    required this.onLocaleChanged,
    super.key,
  });

  final Locale currentLocale;
  final Future<void> Function(Locale locale) onLocaleChanged;

  @override
  State<BilirecHomePage> createState() => _BilirecHomePageState();
}

class _BilirecHomePageState extends State<BilirecHomePage>
    with WidgetsBindingObserver {
  final ServiceSession _session = ServiceSession();
  bool _isIgnoringBatteryOptimizations = false;
  bool _loading = true;
  bool _batteryDialogVisible = false;
  bool _hasShownUnexpectedStopPromptThisSession = false;
  final AppUpdateService _appUpdateService = AppUpdateService();

  AppLocalizations get l10n => AppLocalizations.of(context);

  String get _statusText =>
      l10n.tr(_session.statusKey, params: _session.statusParams);

  String get _currentLanguageCode =>
      AppLocaleConfig.codeForLocale(widget.currentLocale);

  Future<void> _onLanguageSelected(String code) async {
    await widget.onLocaleChanged(AppLocaleConfig.localeForCode(code));
    if (!mounted) return;
    _session.apply(
      statusKey:
          _session.isRunning ? 'backendRunning' : 'backendNotRunning',
      statusParams: const {},
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session.statusKey.isEmpty) {
      _session.setStatus('initializing');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _session.dispose();
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (!mounted) return;
    handleTaskData(_session, data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshServiceState();
      _refreshBatteryOptimizationState();
    }
  }

  Future<void> _refreshServiceState() async {
    final running = await isServiceCoreRunning();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    if (!_session.isInFlight) {
      _session.apply(
        uiState: running ? ServiceUiState.running : ServiceUiState.stopped,
        statusKey: running ? _session.statusKey : 'backendNotRunning',
        statusParams: running ? _session.statusParams : const {},
      );
      if (!running) {
        _session.apply(statusKey: 'backendNotRunning', statusParams: const {});
      }
    }
  }

  Future<void> _bootstrap() async {
    final running = await isServiceCoreRunning();
    final ignoringOptimization = Platform.isAndroid
        ? await FlutterForegroundTask.isIgnoringBatteryOptimizations
        : true;

    if (!mounted) return;
    setState(() {
      _isIgnoringBatteryOptimizations = ignoringOptimization;
      _loading = false;
    });
    _session.apply(
      uiState: running ? ServiceUiState.running : ServiceUiState.stopped,
      desired: running ? ServiceIntent.running : ServiceIntent.stopped,
      statusKey: running ? 'backendRunning' : 'backendNotRunning',
      statusParams: const {},
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupDialogs());
    });
  }

  Future<void> _runStartupDialogs() async {
    await _ensureBatteryDialog();
    await _runFirstLaunchAfterUpdateHooks();
    await _maybeShowUnexpectedStopDialog();
    if (!mounted) return;
    await AppUpdatePrompt(
      context: context,
      l10n: l10n,
      service: _appUpdateService,
    ).checkOnStartup();
  }

  Future<void> _runFirstLaunchAfterUpdateHooks() async {
    if (!Platform.isAndroid || !mounted) return;
    if (!await _appUpdateService.isFirstLaunchAfterUpdate()) return;
    if (!mounted) return;
    await UnexpectedStopPreferences.consumePrompt();
    await _appUpdateService.cleanupDownloadedApks();
    await _appUpdateService.acknowledgeInstalledVersion();
  }

  Future<void> _maybeShowUnexpectedStopDialog() async {
    if (!Platform.isAndroid || !mounted) {
      return;
    }
    if (_hasShownUnexpectedStopPromptThisSession) {
      return;
    }

    final running = await isServiceCoreRunning();
    final snapshot = await UnexpectedStopPreferences.loadSnapshot();
    final autoRunOnBootEnabled = await Preferences.getEnableAutoRunOnBoot();
    final currentBootId = await readBootId();
    final cause = classifyUnexpectedStop(
      serviceRunning: running,
      intendedRunning: snapshot.intendedRunning,
      stoppedByUser: snapshot.stoppedByUser,
      promptMuted: snapshot.promptMuted,
      lastStartId: snapshot.lastStartId,
      consumedStartId: snapshot.consumedStartId,
      lastBootId: snapshot.lastBootId,
      currentBootId: currentBootId,
    );
    final prompt = resolveUnexpectedStopPrompt(
      cause: cause,
      autoRunOnBootEnabled: autoRunOnBootEnabled,
    );
    if (prompt == null || !mounted) {
      return;
    }

    _hasShownUnexpectedStopPromptThisSession = true;
    final action = await showDialog<UnexpectedStopDialogAction>(
      context: context,
      builder: (dialogContext) => UnexpectedStopDialog(prompt: prompt),
    );
    if (!mounted) {
      return;
    }

    await UnexpectedStopPreferences.consumePrompt();
    switch (action) {
      case UnexpectedStopDialogAction.mute:
        await UnexpectedStopPreferences.setPromptMuted(true);
        break;
      case UnexpectedStopDialogAction.enableAutoRunOnBoot:
        await Preferences.setEnableAutoRunOnBoot(true);
        if (!mounted) {
          return;
        }
        showAppToast(context, l10n.tr('unexpectedStopBootEnabledHint'));
        break;
      case UnexpectedStopDialogAction.openOemDocs:
        await launchUrlInSystemBrowser(
          Uri.parse(androidMainlandDocsUrl(widget.currentLocale)),
        );
        break;
      case UnexpectedStopDialogAction.dismiss:
      case null:
        break;
    }
  }

  Future<void> _openFrontendFromUi() async {
    final opened = await openRecordingFrontendUrl(
      context,
      Uri.parse('https://app.bilirec.org'),
    );

    if (!mounted) return;
    if (opened == false) {
      showAppToast(context, l10n.tr('cannotOpenFrontendBrowser'));
    }
  }

  Future<void> _openSettingsSheet() async {
    if (!_isIgnoringBatteryOptimizations) {
      debugLog('跳過設定頁面，因為尚未獲得電池優化豁免');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.95,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          snap: true,
          snapSizes: [0.6, 0.95],
          shouldCloseOnMinExtent: true,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ListenableBuilder(
                listenable: _session,
                builder: (context, _) {
                  return SettingsDrawerSheet(
                    scrollController: scrollController,
                    controlsEnabled:
                        !(_session.isInFlight || _session.isRunning),
                    onClose: () => Navigator.of(sheetContext).pop(),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _refreshBatteryOptimizationState() async {
    if (!Platform.isAndroid) return;

    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!mounted) return;

    setState(() {
      _isIgnoringBatteryOptimizations = ignoring;
    });

    if (ignoring && _batteryDialogVisible) {
      _batteryDialogVisible = false;
      final nav = Navigator.of(context, rootNavigator: true);
      if (mounted && nav.canPop()) {
        nav.pop();
      }
      return;
    }

    _ensureBatteryDialog();
  }

  Future<void> _ensureBatteryDialog() async {
    if (!Platform.isAndroid) return;
    if (_isIgnoringBatteryOptimizations || _batteryDialogVisible || !mounted) {
      return;
    }

    _batteryDialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.tr('batteryDialogTitle')),
            content: Text(l10n.tr('batteryDialogContent')),
            actions: [
              FilledButton.tonal(
                onPressed: _requestBatteryUnrestricted,
                child: Text(l10n.tr('goToSettings')),
              ),
            ],
          ),
        );
      },
    );

    _batteryDialogVisible = false;
  }

  Future<void> _checkLocalhost8080() async {
    final client = HttpClient();
    const toastAnimation = AppToastAnimation.slide;
    const toastLocation = AppToastLocation.top;
    const toastEdgeDistance = 80.0;
    try {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/'))
          .timeout(const Duration(seconds: 2));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      if (!mounted) return;
      final healthy = response.statusCode < 500;
      showAppToast(
        context,
        healthy
            ? '✅ ${l10n.tr('backendHealthy')}'
            : '⚠️ ${l10n.tr('backendUnhealthy')}',
        animation: toastAnimation,
        location: toastLocation,
        edgeDistance: toastEdgeDistance,
      );
    } on TimeoutException {
      if (!mounted) return;
      showAppToast(
        context,
        '⏱️ ${l10n.tr('backendNoResponseHint')}',
        animation: toastAnimation,
        location: toastLocation,
        edgeDistance: toastEdgeDistance,
      );
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        '❌ ${l10n.tr('backendCannotConnect')}',
        animation: toastAnimation,
        location: toastLocation,
        edgeDistance: toastEdgeDistance,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _requestBatteryUnrestricted() async {
    if (!Platform.isAndroid) return;
    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    if (!granted) {
      await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final isServiceRunning = _session.isRunning;
        final actionInFlight = _session.isInFlight;
        final statusColor = isServiceRunning ? Colors.green : Colors.orange;
        final size = MediaQuery.sizeOf(context);
        final buttonGradientColors = actionInFlight
            ? const [
                Color(0xFF4F7BFF),
                Color(0xFF57C6FF),
              ]
            : (isServiceRunning
                ? const [
                    Color(0xFF63B3ED),
                    Color(0xFF4FD1C5),
                  ]
                : const [
                    Color(0xFF9AD9FF),
                    Color(0xFF7FC8FF),
                  ]);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tr('controlCenterTitle')),
            actions: [
              HomePageLanguageMenu(
                currentLanguageCode: _currentLanguageCode,
                onSelected: _onLanguageSelected,
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Stack(
                      children: [
                        ServicePowerButtonArea(
                          size: size,
                          actionInFlight: actionInFlight,
                          isServiceRunning: isServiceRunning,
                          isStarting:
                              _session.uiState == ServiceUiState.starting,
                          isStopping:
                              _session.uiState == ServiceUiState.stopping,
                          buttonGradientColors: buttonGradientColors,
                          onTap: () => toggleBilirecService(
                            host: ServiceToggleHost(
                              session: _session,
                              context: context,
                              l10n: l10n,
                              isIgnoringBatteryOptimizations:
                                  _isIgnoringBatteryOptimizations,
                            ),
                            enable: !isServiceRunning,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ServiceStatusRow(
                                statusColor: statusColor,
                                statusText: _statusText,
                              ),
                              const SizedBox(height: 8),
                              ServiceActionSection(
                                visible: isServiceRunning,
                                onOpenFrontend: _openFrontendFromUi,
                                onCheckBackendConnection: _checkLocalhost8080,
                              ),
                              SettingsCard(
                                enabled: !(actionInFlight || isServiceRunning),
                                onPressed: _openSettingsSheet,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
