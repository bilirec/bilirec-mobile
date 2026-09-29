import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bilirec/shared/github_api_base.dart';
import 'package:bilirec/shared/github_api_probe.dart';

void main() {
  test('probeGitHubApiBase succeeds on 200 JSON object', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{'tag_name': 'v1.0.0'},
            ),
          );
        },
      ),
    );

    expect(
      await probeGitHubApiBase(
        apiBase: 'https://mirror.example.com/',
        dio: dio,
      ),
      isTrue,
    );
  });

  test('probeGitHubApiBase fails on non-200', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 502,
              data: 'bad gateway',
            ),
          );
        },
      ),
    );

    expect(
      await probeGitHubApiBase(
        apiBase: 'https://mirror.example.com/',
        dio: dio,
      ),
      isFalse,
    );
  });

  test('probeGitHubApiBase fails on network error', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
        },
      ),
    );

    expect(
      await probeGitHubApiBase(
        apiBase: 'https://mirror.example.com/',
        dio: dio,
      ),
      isFalse,
    );
  });

  test('webBrowserDownloadUrlFromRelease prefers bilirec-release asset', () {
    final url = webBrowserDownloadUrlFromRelease(<String, dynamic>{
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'other.apk',
          'browser_download_url':
              'https://github.com/bilirec/bilirec-mobile/releases/download/v1/other.apk',
        },
        <String, dynamic>{
          'name': 'bilirec-release.apk',
          'browser_download_url':
              'https://github.com/bilirec/bilirec-mobile/releases/download/v1/bilirec-release.apk',
        },
      ],
    });
    expect(
      url,
      'https://github.com/bilirec/bilirec-mobile/releases/download/v1/bilirec-release.apk',
    );
  });

  test('probeGitHubWebDownloadUrl rewrites and accepts range response', () async {
    const official =
        'https://github.com/bilirec/bilirec-mobile/releases/download/v1/bilirec-release.apk';
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(
            options.uri.toString(),
            'https://gh.bilirec.org/https://github.com/bilirec/bilirec-mobile/releases/download/v1/bilirec-release.apk',
          );
          handler.resolve(
            Response<List<int>>(
              requestOptions: options,
              statusCode: 206,
              data: <int>[0],
            ),
          );
        },
      ),
    );

    expect(
      await probeGitHubWebDownloadUrl(
        githubBase: 'https://gh.bilirec.org/https://github.com/',
        officialDownloadUrl: official,
        dio: dio,
      ),
      isTrue,
    );
  });

  test('probeGitHubWebDownloadUrl skips when github base is official', () async {
    expect(
      await probeGitHubWebDownloadUrl(
        githubBase: '',
        officialDownloadUrl: defaultGitHubWebBase,
      ),
      isTrue,
    );
  });
}
