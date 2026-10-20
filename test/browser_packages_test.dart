import 'dart:typed_data';

import 'package:bilirec/shared/browser_packages.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('org.bilirec.bilirec/browser_packages');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('HttpsBrowserInfo.tryParse accepts package and label', () {
    final info = HttpsBrowserInfo.tryParse({
      'packageName': 'com.example.browser',
      'label': 'Example',
    });
    expect(info?.packageName, 'com.example.browser');
    expect(info?.label, 'Example');
  });

  test('loadHttpsBrowserIcons coerces byte lists from platform channel', () async {
    final fakePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadHttpsBrowserIcons') {
        return <dynamic, dynamic>{
          'com.example.browser': fakePng,
        };
      }
      return null;
    });

    final icons = await loadHttpsBrowserIcons(['com.example.browser']);
    expect(icons['com.example.browser'], fakePng);
  });

  test('loadHttpsBrowserIcons returns empty map on platform error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'loadHttpsBrowserIcons') {
        throw PlatformException(code: 'BROWSER_PACKAGES_FAILED');
      }
      return null;
    });

    final icons = await loadHttpsBrowserIcons(['com.example.browser']);
    expect(icons, isEmpty);
  });
}
