const String defaultGitHubApiBase = 'https://api.github.com/';
const String defaultGitHubWebBase = 'https://github.com/';

/// Human-facing release page when proxy rewrite is off or as open-URL fallback.
/// Change to https://release.bilirec.org/... when the mirror is live.
const String releasePageFallbackUrl =
    'https://github.com/bilirec/bilirec-mobile/releases/latest';

/// Trims and ensures a trailing slash. Empty input means official GitHub.
String normalizeGitHubBaseUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  if (!value.endsWith('/')) {
    value = '$value/';
  }
  return value;
}

/// Alias for API base normalization ([defaultGitHubApiBase] when empty).
String normalizeGitHubApiBaseUrl(String raw) => normalizeGitHubBaseUrl(raw);

bool isOfficialGitHubApiBase(String normalizedBase) {
  if (normalizedBase.isEmpty) {
    return true;
  }
  return normalizedBase.toLowerCase() == defaultGitHubApiBase;
}

bool isOfficialGitHubWebBase(String normalizedBase) {
  if (normalizedBase.isEmpty) {
    return true;
  }
  return normalizedBase.toLowerCase() == defaultGitHubWebBase;
}

String buildGitHubApiReleasesLatestUrl({
  required String owner,
  required String repository,
  required String apiBase,
}) {
  final normalized = normalizeGitHubApiBaseUrl(apiBase);
  final base = isOfficialGitHubApiBase(normalized)
      ? defaultGitHubApiBase
      : normalized;
  return '${base}repos/$owner/$repository/releases/latest';
}

/// Rewrites `https://api.github.com/…` to the configured API base.
String rewriteGitHubApiUrlForProxy(String url, String apiBase) {
  final normalized = normalizeGitHubApiBaseUrl(apiBase);
  if (isOfficialGitHubApiBase(normalized)) {
    return url;
  }
  if (!url.startsWith(defaultGitHubApiBase)) {
    return url;
  }
  return url.replaceFirst(defaultGitHubApiBase, normalized);
}

/// Rewrites `https://github.com/…` to the configured github.com base.
String rewriteGitHubWebUrlForProxy(String url, String githubBase) {
  final normalized = normalizeGitHubBaseUrl(githubBase);
  if (isOfficialGitHubWebBase(normalized)) {
    return url;
  }
  if (!url.startsWith(defaultGitHubWebBase)) {
    return url;
  }
  return url.replaceFirst(defaultGitHubWebBase, normalized);
}
