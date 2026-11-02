import 'package:bilirec/shared/preferences.dart';

/// Base URI of the embedded bilirec backend on localhost.
///
/// The backend binds `127.0.0.1` with `PORT` (default `8080`) in
/// [defaultAndroidEnv]. Users may override `PORT` via the developer
/// environment settings; `HOST` is not read because the app only ever
/// talks to the loopback interface on-device.
Future<Uri> backendBaseUri() async {
  final port = await _backendPort();
  return Uri.parse('http://127.0.0.1:$port');
}

Future<int> _backendPort() async {
  try {
    final develop = await Preferences.getDevelopEnvironmentSettings();
    final raw = (develop['PORT'] ?? '').trim();
    final port = int.tryParse(raw);
    if (port == null || port <= 0 || port > 65535) {
      return 8080;
    }
    return port;
  } catch (_) {
    return 8080;
  }
}
