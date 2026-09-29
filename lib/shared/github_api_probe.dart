import 'package:dio/dio.dart';

import 'package:bilirec/shared/github_api_base.dart';

const String _probeOwner = 'bilirec';
const String _probeRepository = 'bilirec-mobile';
const String _probeApkAssetKey = 'bilirec-release';

class GitHubLatestReleaseProbe {
  const GitHubLatestReleaseProbe({
    required this.reachable,
    this.release,
  });

  final bool reachable;
  final Map<String, dynamic>? release;
}

Dio _probeDio({
  Dio? dio,
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 12),
}) {
  return dio ??
      Dio(
        BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ),
      );
}

/// Fetches latest release JSON the same way update checks do.
Future<GitHubLatestReleaseProbe> fetchGitHubLatestRelease({
  required String apiBase,
  Dio? dio,
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 12),
}) async {
  final client = _probeDio(
    dio: dio,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
  );
  try {
    final url = buildGitHubApiReleasesLatestUrl(
      owner: _probeOwner,
      repository: _probeRepository,
      apiBase: apiBase,
    );
    final response = await client.get<dynamic>(
      url,
      options: Options(
        headers: const <String, String>{
          'Accept': 'application/vnd.github.v3+json',
        },
      ),
    );
    if (response.statusCode != 200) {
      return const GitHubLatestReleaseProbe(reachable: false);
    }
    final data = response.data;
    if (data is Map<String, dynamic> && data.isNotEmpty) {
      return GitHubLatestReleaseProbe(reachable: true, release: data);
    }
    if (data is Map && data.isNotEmpty) {
      return GitHubLatestReleaseProbe(
        reachable: true,
        release: Map<String, dynamic>.from(data),
      );
    }
    return const GitHubLatestReleaseProbe(reachable: false);
  } on DioException {
    return const GitHubLatestReleaseProbe(reachable: false);
  } catch (_) {
    return const GitHubLatestReleaseProbe(reachable: false);
  }
}

/// Lightweight reachability check using the same releases/latest URL as update checks.
Future<bool> probeGitHubApiBase({
  required String apiBase,
  Dio? dio,
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 12),
}) async {
  final result = await fetchGitHubLatestRelease(
    apiBase: apiBase,
    dio: dio,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
  );
  return result.reachable;
}

/// Picks a `browser_download_url` on github.com for download proxy probes.
String? webBrowserDownloadUrlFromRelease(Map<String, dynamic> release) {
  final assets = release['assets'];
  if (assets is! List) {
    return null;
  }
  String? fallback;
  for (final item in assets) {
    if (item is! Map) {
      continue;
    }
    final url = item['browser_download_url'];
    if (url is! String || !url.startsWith(defaultGitHubWebBase)) {
      continue;
    }
    fallback ??= url;
    final name = item['name'];
    if (name is String && name.contains(_probeApkAssetKey)) {
      return url;
    }
  }
  return fallback;
}

/// Checks that a proxied release download URL responds (range GET).
Future<bool> probeGitHubWebDownloadUrl({
  required String githubBase,
  required String officialDownloadUrl,
  Dio? dio,
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 12),
}) async {
  final normalized = normalizeGitHubBaseUrl(githubBase);
  if (isOfficialGitHubWebBase(normalized)) {
    return true;
  }
  final url = rewriteGitHubWebUrlForProxy(officialDownloadUrl, githubBase);
  final client = _probeDio(
    dio: dio,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
  );
  try {
    final response = await client.get<List<int>>(
      url,
      options: Options(
        headers: const <String, String>{'Range': 'bytes=0-0'},
        responseType: ResponseType.bytes,
        validateStatus: (status) =>
            status != null && (status == 200 || status == 206),
      ),
    );
    return response.statusCode == 200 || response.statusCode == 206;
  } on DioException {
    return false;
  } catch (_) {
    return false;
  }
}
