import 'package:bilirec/shared/github_api_base.dart';

/// Preset id for [Preferences] / settings UI (not an API URL).
const String githubApiProxyPresetOfficial = 'official';
const String githubApiProxyPresetCustom = 'custom';

/// Environment variable name passed to libbilirec when a proxy base is set.
const String githubApiUrlEnvKey = 'GITHUB_API_URL';

class GitHubApiProxyPreset {
  const GitHubApiProxyPreset({
    required this.id,
    required this.apiBaseUrl,
  });

  final String id;

  /// Full go-github `BaseURL` (with trailing slash). Prefix-style and host-mirror
  /// proxies use different shapes — set the value your provider documents.
  final String apiBaseUrl;

  /// Dropdown label derived from [apiBaseUrl] host.
  String get label {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return id;
  }

  String get normalizedApiBaseUrl => normalizeGitHubApiBaseUrl(apiBaseUrl);
}

/// Built-in GitHub API proxy presets. Extend by adding one [GitHubApiProxyPreset] row.
const List<GitHubApiProxyPreset> kGitHubApiProxyPresets = <GitHubApiProxyPreset>[
  GitHubApiProxyPreset(
    id: 'gh_proxy_com',
    apiBaseUrl: 'https://gh-proxy.com/https://api.github.com/',
  ),
  GitHubApiProxyPreset(
    id: 'gh_proxy_org',
    apiBaseUrl: 'https://gh-proxy.org/https://api.github.com/',
  ),
];

GitHubApiProxyPreset? githubApiProxyPresetById(String id) {
  for (final preset in kGitHubApiProxyPresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return null;
}

/// Maps stored preference value to a preset id or [githubApiProxyPresetCustom].
String githubApiProxyPresetIdFromStored(String? stored) {
  final normalized = normalizeGitHubApiBaseUrl(stored ?? '');
  if (isOfficialGitHubApiBase(normalized)) {
    return githubApiProxyPresetOfficial;
  }
  for (final preset in kGitHubApiProxyPresets) {
    if (preset.normalizedApiBaseUrl == normalized) {
      return preset.id;
    }
  }
  return githubApiProxyPresetCustom;
}

String githubApiBaseUrlForPresetId(String presetId, String customInput) {
  if (presetId == githubApiProxyPresetOfficial) {
    return '';
  }
  if (presetId == githubApiProxyPresetCustom) {
    return normalizeGitHubApiBaseUrl(customInput);
  }
  final preset = githubApiProxyPresetById(presetId);
  if (preset == null) {
    return '';
  }
  return preset.normalizedApiBaseUrl;
}

/// Env entries for libbilirec `StartConfig.env` (omit when using official API).
Map<String, String> githubApiUrlEnvFromStored(String? stored) {
  final normalized = normalizeGitHubApiBaseUrl(stored ?? '');
  if (isOfficialGitHubApiBase(normalized)) {
    return const <String, String>{};
  }
  return <String, String>{githubApiUrlEnvKey: normalized};
}
