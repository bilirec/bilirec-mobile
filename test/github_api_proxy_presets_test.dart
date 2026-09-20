import 'package:bilirec/shared/github_api_proxy_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preset id from stored URL', () {
    expect(githubApiProxyPresetIdFromStored(null), githubApiProxyPresetOfficial);
    final first = kGitHubApiProxyPresets.first;
    expect(
      githubApiProxyPresetIdFromStored(first.normalizedApiBaseUrl),
      first.id,
    );
    expect(
      githubApiProxyPresetIdFromStored('https://example.com/proxy/'),
      githubApiProxyPresetCustom,
    );
  });

  test('base URL for preset id', () {
    expect(
      githubApiBaseUrlForPresetId(githubApiProxyPresetOfficial, ''),
      '',
    );
    final second = kGitHubApiProxyPresets[1];
    expect(
      githubApiBaseUrlForPresetId(second.id, ''),
      second.normalizedApiBaseUrl,
    );
  });

  test('preset label from proxy root host', () {
    expect(kGitHubApiProxyPresets.first.label, 'gh-proxy.com');
  });
}
