import 'package:flutter/services.dart';

class HttpsBrowserInfo {
  const HttpsBrowserInfo({
    required this.packageName,
    required this.label,
  });

  final String packageName;
  final String label;

  static HttpsBrowserInfo? tryParse(Map<dynamic, dynamic> raw) {
    final packageName = raw['packageName']?.toString();
    final label = raw['label']?.toString();
    if (packageName == null || packageName.isEmpty) {
      return null;
    }
    return HttpsBrowserInfo(
      packageName: packageName,
      label: (label == null || label.isEmpty) ? packageName : label,
    );
  }
}

const MethodChannel _browserPackagesChannel =
    MethodChannel('org.bilirec.bilirec/browser_packages');

Future<List<HttpsBrowserInfo>> listHttpsBrowsers() async {
  final raw = await _browserPackagesChannel.invokeMethod<List<dynamic>>(
    'listHttpsBrowsers',
  );
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map(HttpsBrowserInfo.tryParse)
      .whereType<HttpsBrowserInfo>()
      .toList();
}
