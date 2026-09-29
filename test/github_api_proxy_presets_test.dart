import 'package:bilirec/shared/github_api_proxy_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preset id from stored URL', () {
    expect(
      githubApiProxyPresetIdFromStored(apiBase: null, githubBase: null),
      githubApiProxyPresetOfficial,
    );
    final first = kGitHubApiProxyPresets.first;
    expect(
      githubApiProxyPresetIdFromStored(
        apiBase: first.normalizedApiBaseUrl,
        githubBase: first.normalizedGithubBaseUrl,
      ),
      first.id,
    );
    expect(
      githubApiProxyPresetIdFromStored(
        apiBase: 'https://example.com/proxy/',
        githubBase: '',
      ),
      githubApiProxyPresetCustom,
    );
  });

  test('proxy settings for preset id', () {
    expect(
      githubProxySettingsForPresetId(githubApiProxyPresetOfficial),
      const GitHubProxySettings(
        apiBaseUrl: '',
        githubBaseUrl: '',
      ),
    );
    final second = kGitHubApiProxyPresets[1];
    expect(
      githubProxySettingsForPresetId(second.id),
      GitHubProxySettings(
        apiBaseUrl: second.normalizedApiBaseUrl,
        githubBaseUrl: second.normalizedGithubBaseUrl,
      ),
    );
  });

  test('preset label from proxy root host', () {
    expect(kGitHubApiProxyPresets.first.label, 'gh.bilirec.org');
  });
}
