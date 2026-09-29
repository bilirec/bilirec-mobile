import 'package:bilirec/shared/github_api_base.dart';

/// Preset id for [Preferences] / settings UI (not an API URL).
const String githubApiProxyPresetOfficial = 'official';
const String githubApiProxyPresetCustom = 'custom';

/// Environment variable name passed to libbilirec when a proxy base is set.
const String githubApiUrlEnvKey = 'GITHUB_API_URL';

class GitHubProxySettings {
  const GitHubProxySettings({
    required this.apiBaseUrl,
    required this.githubBaseUrl,
  });

  final String apiBaseUrl;
  final String githubBaseUrl;

  @override
  bool operator ==(Object other) {
    return other is GitHubProxySettings &&
        apiBaseUrl == other.apiBaseUrl &&
        githubBaseUrl == other.githubBaseUrl;
  }

  @override
  int get hashCode => Object.hash(apiBaseUrl, githubBaseUrl);
}

class GitHubApiProxyPreset {
  const GitHubApiProxyPreset({
    required this.id,
    required this.apiBaseUrl,
    required this.githubBaseUrl,
  });

  final String id;

  /// Full go-github `BaseURL` (with trailing slash).
  final String apiBaseUrl;

  /// Replacement base for `https://github.com/` (APK download URLs).
  final String githubBaseUrl;

  /// Dropdown label derived from [apiBaseUrl] host.
  String get label {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return id;
  }

  String get normalizedApiBaseUrl => normalizeGitHubApiBaseUrl(apiBaseUrl);

  String get normalizedGithubBaseUrl =>
      normalizeGitHubBaseUrl(githubBaseUrl);
}

/// Built-in GitHub API proxy presets. Extend by adding one [GitHubApiProxyPreset] row.
const List<GitHubApiProxyPreset> kGitHubApiProxyPresets = <GitHubApiProxyPreset>[
  GitHubApiProxyPreset(
    id: 'gh_bilirec_org',
    apiBaseUrl: 'https://gh.bilirec.org/https://api.github.com/',
    githubBaseUrl: 'https://gh.bilirec.org/https://github.com/',
  ),
  GitHubApiProxyPreset(
    id: 'gh_proxy_com',
    apiBaseUrl: 'https://gh-proxy.com/https://api.github.com/',
    githubBaseUrl: 'https://gh-proxy.com/https://github.com/',
  ),
  GitHubApiProxyPreset(
    id: 'gh_proxy_org',
    apiBaseUrl: 'https://gh-proxy.org/https://api.github.com/',
    githubBaseUrl: 'https://gh-proxy.org/https://github.com/',
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

/// Maps stored preference values to a preset id or [githubApiProxyPresetCustom].
String githubApiProxyPresetIdFromStored({
  String? apiBase,
  String? githubBase,
}) {
  final normalizedApi = normalizeGitHubApiBaseUrl(apiBase ?? '');
  final normalizedGithub = normalizeGitHubBaseUrl(githubBase ?? '');
  if (isOfficialGitHubApiBase(normalizedApi) &&
      isOfficialGitHubWebBase(normalizedGithub)) {
    return githubApiProxyPresetOfficial;
  }
  for (final preset in kGitHubApiProxyPresets) {
    if (preset.normalizedApiBaseUrl == normalizedApi &&
        preset.normalizedGithubBaseUrl == normalizedGithub) {
      return preset.id;
    }
  }
  return githubApiProxyPresetCustom;
}

GitHubProxySettings githubProxySettingsForPresetId(
  String presetId, {
  String customApiInput = '',
  String customGithubInput = '',
}) {
  if (presetId == githubApiProxyPresetOfficial) {
    return const GitHubProxySettings(
      apiBaseUrl: '',
      githubBaseUrl: '',
    );
  }
  if (presetId == githubApiProxyPresetCustom) {
    return GitHubProxySettings(
      apiBaseUrl: normalizeGitHubApiBaseUrl(customApiInput),
      githubBaseUrl: normalizeGitHubBaseUrl(customGithubInput),
    );
  }
  final preset = githubApiProxyPresetById(presetId);
  if (preset == null) {
    return const GitHubProxySettings(
      apiBaseUrl: '',
      githubBaseUrl: '',
    );
  }
  return GitHubProxySettings(
    apiBaseUrl: preset.normalizedApiBaseUrl,
    githubBaseUrl: preset.normalizedGithubBaseUrl,
  );
}

/// Env entries for libbilirec `StartConfig.env` (omit when using official API).
Map<String, String> githubApiUrlEnvFromStored(String? stored) {
  final normalized = normalizeGitHubApiBaseUrl(stored ?? '');
  if (isOfficialGitHubApiBase(normalized)) {
    return const <String, String>{};
  }
  return <String, String>{githubApiUrlEnvKey: normalized};
}
