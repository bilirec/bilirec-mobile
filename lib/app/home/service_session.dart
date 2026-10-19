import 'package:flutter/foundation.dart';

enum ServiceUiState { stopped, starting, running, stopping }

enum ServiceIntent { stopped, running }

class ServiceSession extends ChangeNotifier {
  ServiceUiState uiState = ServiceUiState.stopped;
  ServiceIntent desired = ServiceIntent.stopped;
  int _latestRequestId = 0;
  int healthCheckEpoch = 0;
  String statusKey = 'initializing';
  Map<String, String> statusParams = const {};

  bool get isRunning => uiState == ServiceUiState.running;

  bool get isInFlight =>
      uiState == ServiceUiState.starting || uiState == ServiceUiState.stopping;

  int get latestRequestId => _latestRequestId;

  int begin(ServiceIntent intent) {
    desired = intent;
    healthCheckEpoch++;
    return ++_latestRequestId;
  }

  bool isLatest(int requestId) => requestId == _latestRequestId;

  int nextHealthEpoch() => ++healthCheckEpoch;

  void apply({
    ServiceUiState? uiState,
    ServiceIntent? desired,
    String? statusKey,
    Map<String, String>? statusParams,
  }) {
    if (uiState != null) {
      this.uiState = uiState;
    }
    if (desired != null) {
      this.desired = desired;
    }
    if (statusKey != null) {
      this.statusKey = statusKey;
    }
    if (statusParams != null) {
      this.statusParams = statusParams;
    }
    notifyListeners();
  }

  void setStatus(String key, {Map<String, String> params = const {}}) {
    statusKey = key;
    statusParams = params;
  }
}
