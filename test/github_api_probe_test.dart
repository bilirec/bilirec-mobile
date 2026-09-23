import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
