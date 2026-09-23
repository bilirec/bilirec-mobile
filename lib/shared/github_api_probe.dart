import 'package:dio/dio.dart';

import 'package:bilirec/shared/github_api_base.dart';

const String _probeOwner = 'bilirec';
const String _probeRepository = 'bilirec-mobile';

/// Lightweight reachability check using the same releases/latest URL as update checks.
Future<bool> probeGitHubApiBase({
  required String apiBase,
  Dio? dio,
  Duration connectTimeout = const Duration(seconds: 12),
  Duration receiveTimeout = const Duration(seconds: 12),
}) async {
  final client = dio ??
      Dio(
        BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
        ),
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
      return false;
    }
    final data = response.data;
    return data is Map && data.isNotEmpty;
  } on DioException {
    return false;
  } catch (_) {
    return false;
  }
}
