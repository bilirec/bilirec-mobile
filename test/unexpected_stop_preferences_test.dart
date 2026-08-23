import 'package:bilirec/shared/unexpected_stop_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'test_support/in_memory_shared_preferences_async_platform.dart';

void main() {
  final fakeAsyncPrefs = InMemorySharedPreferencesAsyncPlatform();
  final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance = fakeAsyncPrefs;
  });

  tearDownAll(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
  });

  setUp(fakeAsyncPrefs.reset);

  test('markServiceStarted 寫入檢測狀態並清掉使用者停止旗標', () async {
    await UnexpectedStopPreferences.setStoppedByUser(true);

    await UnexpectedStopPreferences.markServiceStarted();

    expect(await UnexpectedStopPreferences.getStoppedByUser(), isFalse);
    expect(await UnexpectedStopPreferences.getIntendedRunning(), isTrue);
    expect(await UnexpectedStopPreferences.getLastStartId(), isNotNull);
  });

  test('markServiceStarted 會寫入 boot_id', () async {
    await UnexpectedStopPreferences.markServiceStarted(
      bootId: 'boot-1',
    );

    expect(await UnexpectedStopPreferences.getLastBootId(), 'boot-1');
  });

  test('consumePrompt 只對同一輪啟動生效', () async {
    await UnexpectedStopPreferences.markServiceStarted();
    final startId = await UnexpectedStopPreferences.getLastStartId();

    await UnexpectedStopPreferences.consumePrompt();

    expect(
      await UnexpectedStopPreferences.getPromptConsumedStartId(),
      startId,
    );
  });

  test('markStoppedByUser 與 restoreAfterFailedStop 只動檢測意圖', () async {
    await UnexpectedStopPreferences.markServiceStarted();
    await UnexpectedStopPreferences.markStoppedByUser();

    expect(await UnexpectedStopPreferences.getStoppedByUser(), isTrue);
    expect(await UnexpectedStopPreferences.getIntendedRunning(), isFalse);

    await UnexpectedStopPreferences.restoreAfterFailedStop();

    expect(await UnexpectedStopPreferences.getStoppedByUser(), isFalse);
    expect(await UnexpectedStopPreferences.getIntendedRunning(), isTrue);
  });

  test('getStoppedByUser 會把舊鍵 stopped_by_user 遷到檢測用偏好', () async {
    await SharedPreferencesAsync().setBool('stopped_by_user', true);

    expect(await UnexpectedStopPreferences.getStoppedByUser(), isTrue);
    expect(
      await SharedPreferencesAsync().getBool('unexpected_stop.stopped_by_user'),
      isTrue,
    );
    expect(await SharedPreferencesAsync().getBool('stopped_by_user'), isNull);
  });
}
