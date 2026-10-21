import 'dart:typed_data';

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

/// Returns PNG bytes keyed by package name. Missing or failed icons are omitted.
Future<Map<String, Uint8List>> loadHttpsBrowserIcons(
  List<String> packageNames,
) async {
  if (packageNames.isEmpty) {
    return const {};
  }
  try {
    final raw = await _browserPackagesChannel.invokeMethod<Map<dynamic, dynamic>>(
      'loadHttpsBrowserIcons',
      <String, dynamic>{'packageNames': packageNames},
    );
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    final out = <String, Uint8List>{};
    for (final entry in raw.entries) {
      final packageName = entry.key.toString();
      final bytes = _coerceToUint8List(entry.value);
      if (packageName.isEmpty || bytes == null || bytes.isEmpty) {
        continue;
      }
      out[packageName] = bytes;
    }
    return out;
  } on PlatformException {
    return const {};
  } on MissingPluginException {
    return const {};
  }
}

Uint8List? _coerceToUint8List(Object? value) {
  if (value is Uint8List) {
    return value;
  }
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  return null;
}
