import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:github_release_apk_updater/github_release_apk_updater.dart';

import 'package:bilirec/shared/github_api_base.dart';

/// [GithubApiService] that honors a configurable GitHub API base URL.
class ConfigurableGithubApiService extends GithubApiService {
  ConfigurableGithubApiService({
    Dio? dio,
    this.apiBaseUrl = '',
  })  : _dio = dio ?? Dio(),
        super(dio: dio);

  final Dio _dio;
  final String apiBaseUrl;

  @override
  Future<GithubAPKRelease?> getLatestGithubAPKRelease({
    required String ownerGithub,
    required String repositoryGithub,
    required String apkKeyName,
    String? tokenGithub,
    List<String>? supportedAbis,
  }) async {
    try {
      final url = buildGitHubApiReleasesLatestUrl(
        owner: ownerGithub,
        repository: repositoryGithub,
        apiBase: apiBaseUrl,
      );
      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
      };

      if (tokenGithub != null && tokenGithub.isNotEmpty) {
        headers['Authorization'] = 'Bearer $tokenGithub';
      }

      final response = await _dio.get(url, options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final release = GithubAPKRelease.fromJson(
          data,
          apkKeyName,
          supportedAbis: supportedAbis,
        );
        return GithubAPKRelease(
          version: release.version,
          releaseNote: release.releaseNote,
          apkUrl: rewriteGitHubUrlForProxy(release.apkUrl, apiBaseUrl),
        );
      }
      debugPrint(
        'Failed to load release from github API. Status code: ${response.statusCode}',
      );
    } on DioException catch (e) {
      debugPrint(
        'DioException fetching release info from GitHub: ${e.message}',
      );
    } catch (e) {
      debugPrint('Error fetching release info from GitHub: $e');
    }
    return null;
  }
}
