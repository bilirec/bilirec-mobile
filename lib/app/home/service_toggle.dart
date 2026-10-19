import 'dart:async';
import 'dart:io';

import 'package:bilirec/app/home/service_session.dart';
import 'package:bilirec/foreground/bilirec_task_handler.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/app_toast.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/external_storage_permission_prompt.dart';
import 'package:bilirec/shared/legacy_android_compatible.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:bilirec/shared/unexpected_stop_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BilirecTaskHandler());
}

class ServiceToggleHost {
  ServiceToggleHost({
    required this.session,
    required this.context,
    required this.l10n,
    required this.isIgnoringBatteryOptimizations,
  });

  final ServiceSession session;
  final BuildContext context;
  final AppLocalizations l10n;
  final bool isIgnoringBatteryOptimizations;

  bool get mounted => context.mounted;
}

Future<bool> isServiceCoreRunning() async {
  try {
    final running = await FlutterForegroundTask.isRunningService;
    final healthy =
        await FlutterForegroundTask.getData(key: coreRunningKey) as bool? ??
            false;
    return running && healthy;
  } catch (_) {
    return false;
  }
}

Future<void> stopForegroundIfRunning() async {
  try {
    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      await FlutterForegroundTask.stopService();
    }
  } catch (_) {
    // ignore, UI state will still be reconciled by refresh/task callbacks
  }
}

Future<void> confirmRunning(ServiceSession session, int requestId) async {
  final epoch = session.nextHealthEpoch();
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (DateTime.now().isBefore(deadline)) {
    if (!session.isLatest(requestId) ||
        session.desired != ServiceIntent.running ||
        epoch != session.healthCheckEpoch) {
      return;
    }

    final running = await isServiceCoreRunning();
    if (running) {
      if (!session.isLatest(requestId) ||
          session.desired != ServiceIntent.running ||
          epoch != session.healthCheckEpoch) {
        return;
      }
      session.apply(
        uiState: ServiceUiState.running,
        statusKey: 'backendRunning',
        statusParams: const {},
      );
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  if (!session.isLatest(requestId) ||
      session.desired != ServiceIntent.running ||
      epoch != session.healthCheckEpoch) {
    return;
  }

  await stopForegroundIfRunning();
  if (!session.isLatest(requestId)) return;
  session.apply(
    uiState: ServiceUiState.stopped,
    desired: ServiceIntent.stopped,
    statusKey: 'backendNoResponse',
    statusParams: const {},
  );
}

Future<void> confirmStopped(
  ServiceSession session,
  int requestId, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final epoch = session.nextHealthEpoch();
  await Future<void>.delayed(timeout);

  if (!session.isLatest(requestId) ||
      session.desired != ServiceIntent.stopped ||
      epoch != session.healthCheckEpoch) {
    return;
  }

  if (session.uiState != ServiceUiState.stopping) {
    return;
  }

  var stillRunning = true;
  Object? runtimeError;
  try {
    stillRunning = await FlutterForegroundTask.isRunningService;
  } catch (e) {
    runtimeError = e;
  }

  if (!session.isLatest(requestId) ||
      session.desired != ServiceIntent.stopped ||
      epoch != session.healthCheckEpoch) {
    return;
  }

  if (!stillRunning) {
    session.apply(
      uiState: ServiceUiState.stopped,
      desired: ServiceIntent.stopped,
      statusKey: 'backendStopped',
      statusParams: const {},
    );
    return;
  }

  debugLog(
    '[STOP/UI] confirm stop timeout, reconcile state to running (runtimeError=${runtimeError ?? '<none>'})',
  );
  session.apply(
    uiState: ServiceUiState.running,
    desired: ServiceIntent.running,
    statusKey: 'backendRunning',
    statusParams: const {},
  );
}

void handleTaskData(ServiceSession session, Object data) {
  if (data is! Map) return;

  final type = data['type']?.toString();

  switch (type) {
    case 'service_started':
      if (session.desired != ServiceIntent.running) {
        break;
      }
      final ok = data['ok'] == true;
      final result = data['result'];
      final requestId = session.latestRequestId;
      if (ok) {
        session.apply(
          uiState: ServiceUiState.starting,
          statusKey: 'foregroundStartWaitingCore',
          statusParams: const {},
        );
        unawaited(confirmRunning(session, requestId));
      } else if (result == 1) {
        session.apply(
          uiState: ServiceUiState.stopped,
          desired: ServiceIntent.stopped,
          statusKey: 'serviceStartFailedNativeExit',
          statusParams: const {},
        );
        unawaited(stopForegroundIfRunning());
      } else {
        session.apply(
          uiState: ServiceUiState.stopped,
          desired: ServiceIntent.stopped,
          statusKey: 'serviceStartFailedWithCode',
          statusParams: {'code': '$result'},
        );
        unawaited(stopForegroundIfRunning());
      }
      break;
    case 'service_stopped':
      if (session.desired == ServiceIntent.running && session.isInFlight) {
        break;
      }
      final stoppedByUser = data['stoppedByUser'] == true;
      session.apply(
        uiState: ServiceUiState.stopped,
        desired: ServiceIntent.stopped,
        statusKey: stoppedByUser ? 'backendStopped' : 'backendNotRunning',
        statusParams: const {},
      );
      break;
    case 'backend_dead':
      final stoppedByUser = data['stoppedByUser'] == true;
      session.apply(
        uiState: ServiceUiState.stopped,
        desired: ServiceIntent.stopped,
        statusKey: 'backendNoResponse',
        statusParams: const {},
      );
      if (!stoppedByUser) {
        unawaited(stopForegroundIfRunning());
      }
      break;
    default:
      break;
  }
}

Future<void> yieldToNextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  });
  return completer.future;
}

Future<void> toggleBilirecService({
  required ServiceToggleHost host,
  required bool enable,
}) async {
  final session = host.session;
  if (!Platform.isAndroid) {
    session.apply(statusKey: 'androidOnly', statusParams: const {});
    return;
  }

  if (session.isInFlight) {
    return;
  }

  try {
    if (enable) {
      if (!host.isIgnoringBatteryOptimizations) {
        debugLog('跳過服務啟動，因為尚未獲得電池優化豁免');
        return;
      }

      final outputDir = await Preferences.getOutputDir();
      if (!host.mounted) return;
      if (outputDir != null && outputDir.isNotEmpty) {
        final permissionGranted =
            await ensureExternalStoragePermissionWithPrompt(
          context: host.context,
          dialogTitle:
              host.l10n.tr('startServiceExternalPathPermissionDialogTitle'),
          dialogContent:
              host.l10n.tr('startServiceExternalPathPermissionDialogContent'),
          confirmLabel:
              host.l10n.tr('startServiceExternalPathPermissionDialogConfirm'),
          deniedToastMessage: host.l10n.tr('externalStoragePermissionDenied'),
          showToast: (message) => showAppToast(host.context, message),
          targetPath: outputDir,
          promptOnlyForExternalPath: true,
          showDeniedToastBeforePrompt: true,
          showDeniedToastAfterDenied: false,
        );
        if (!permissionGranted) {
          if (!host.mounted) return;
          session.apply(
            statusKey: 'externalStoragePermissionDenied',
            statusParams: const {},
          );
          return;
        }

        final writable =
            await ensureDirectoryWritableWithPermissionFromVersion(outputDir);
        if (!writable) {
          if (!host.mounted) return;
          session.apply(
            statusKey: 'externalStoragePermissionDenied',
            statusParams: const {},
          );
          showAppToast(
            host.context,
            host.l10n.tr('externalStoragePermissionDenied'),
          );
          return;
        }
      }

      final requestId = session.begin(ServiceIntent.running);
      session.apply(
        uiState: ServiceUiState.starting,
        statusKey: 'startingService',
        statusParams: const {},
      );

      if (!session.isLatest(requestId) || !host.mounted) return;
      await Future.delayed(const Duration(seconds: 1));

      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        final requested =
            await FlutterForegroundTask.requestNotificationPermission();
        if (requested != NotificationPermission.granted) {
          if (!session.isLatest(requestId) || !host.mounted) return;
          session.apply(
            uiState: ServiceUiState.stopped,
            desired: ServiceIntent.stopped,
            statusKey: 'notificationPermissionDenied',
            statusParams: const {},
          );
          return;
        }
      }

      final usingAntiSleep = await Preferences.getEnableAntiSleep();
      final autoRunOnBoot = await Preferences.getEnableAutoRunOnBoot();

      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'bilirec_service_channel',
          channelName: 'Bilirec 服務狀態',
          channelDescription: '顯示 Bilirec 服務目前是否運作中',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
          playSound: false,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(15000),
          autoRunOnBoot: autoRunOnBoot,
          autoRunOnMyPackageReplaced: true,
          allowWakeLock: true,
          allowWifiLock: !usingAntiSleep,
        ),
      );

      final serviceTypes = await getForegroundServiceTypesFromVersion();
      final started = await FlutterForegroundTask.startService(
        serviceId: 2026,
        notificationTitle: host.l10n.tr('notificationTitleRunning'),
        notificationText: host.l10n.tr('notificationTextRunning'),
        notificationButtons: [
          NotificationButton(
              id: 'stop', text: host.l10n.tr('notificationButtonStop')),
        ],
        serviceTypes: serviceTypes,
        callback: startCallback,
      );

      final ok = started is ServiceRequestSuccess;

      if (!session.isLatest(requestId) || !host.mounted) {
        return;
      }

      session.apply(
        uiState: ok ? ServiceUiState.starting : ServiceUiState.stopped,
        desired: ok ? session.desired : ServiceIntent.stopped,
        statusKey: ok ? 'foregroundStartWaitingCore' : 'foregroundStartFailed',
        statusParams: const {},
      );
      if (ok) {
        unawaited(confirmRunning(session, requestId));
      }
    } else {
      final requestId = session.begin(ServiceIntent.stopped);
      final stopOpId = DateTime.now().microsecondsSinceEpoch;
      final stopSw = Stopwatch()..start();
      debugLog('[STOP/UI][$stopOpId] requested (requestId=$requestId)');
      session.apply(uiState: ServiceUiState.stopping);

      debugLog('[STOP/UI][$stopOpId] before _yieldToNextFrame');
      await yieldToNextFrame();
      debugLog(
          '[STOP/UI][$stopOpId] after _yieldToNextFrame (${stopSw.elapsedMilliseconds}ms)');
      if (!session.isLatest(requestId) || !host.mounted) return;
      await Future.delayed(const Duration(seconds: 1));

      debugLog('[STOP/UI][$stopOpId] before markStoppedByUser()');
      await UnexpectedStopPreferences.markStoppedByUser();
      debugLog(
          '[STOP/UI][$stopOpId] after markStoppedByUser() (${stopSw.elapsedMilliseconds}ms)');
      debugLog(
          '[STOP/UI][$stopOpId] before FlutterForegroundTask.stopService()');
      final stopped = await FlutterForegroundTask.stopService();
      debugLog(
          '[STOP/UI][$stopOpId] after FlutterForegroundTask.stopService() (${stopSw.elapsedMilliseconds}ms) result=$stopped');
      final ok = stopped is ServiceRequestSuccess;
      if (!session.isLatest(requestId) || !host.mounted) {
        return;
      }
      session.apply(
        uiState: ok ? ServiceUiState.stopping : ServiceUiState.running,
        desired: ok ? ServiceIntent.stopped : ServiceIntent.running,
        statusKey: ok ? 'foregroundStopWaitingCore' : 'stopServiceFailed',
        statusParams: const {},
      );
      if (ok) {
        unawaited(confirmStopped(session, requestId));
      } else {
        await UnexpectedStopPreferences.restoreAfterFailedStop();
      }
      debugLog(
          '[STOP/UI][$stopOpId] completed (ok=$ok, total=${stopSw.elapsedMilliseconds}ms)');
    }
  } catch (e, stackTrace) {
    debugLog('[STOP/UI] failed: $e');
    debugLog('$stackTrace');
    session.apply(
      uiState: ServiceUiState.stopped,
      desired: ServiceIntent.stopped,
      statusKey: 'serviceOperationFailed',
      statusParams: {'error': '$e'},
    );
  }
}
