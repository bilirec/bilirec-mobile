const String defaultGitHubApiBase = 'https://api.github.com/';

/// Human-facing release page when proxy rewrite is off or as open-URL fallback.
/// Change to https://release.bilirec.org/... when the mirror is live.
const String releasePageFallbackUrl =
    'https://github.com/bilirec/bilirec-mobile/releases/latest';

/// Trims and ensures a trailing slash. Does not guess proxy URL shape.
/// Empty input means use the official GitHub API ([defaultGitHubApiBase]).
String normalizeGitHubApiBaseUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  if (!value.endsWith('/')) {
    value = '$value/';
  }
  return value;
}

bool isOfficialGitHubApiBase(String normalizedBase) {
  if (normalizedBase.isEmpty) {
    return true;
  }
  return normalizedBase.toLowerCase() == defaultGitHubApiBase;
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

/// Rewrites `https://api.github.com/…` asset URLs to match the configured API base.
String rewriteGitHubUrlForProxy(String url, String apiBase) {
  final normalized = normalizeGitHubApiBaseUrl(apiBase);
  if (isOfficialGitHubApiBase(normalized)) {
    return url;
  }
  const officialHttps = 'https://api.github.com/';
  const officialHttp = 'http://api.github.com/';
  if (url.startsWith(officialHttps)) {
    return url.replaceFirst(officialHttps, normalized);
  }
  if (url.startsWith(officialHttp)) {
    final httpBase = normalized.replaceFirst('https://', 'http://');
    return url.replaceFirst(officialHttp, httpBase);
  }
  return url;
}
