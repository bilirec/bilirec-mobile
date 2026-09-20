import 'package:bilirec/shared/github_api_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeGitHubApiBaseUrl does not reshape proxy URLs', () {
    expect(normalizeGitHubApiBaseUrl(''), '');
    expect(
      normalizeGitHubApiBaseUrl('https://gh-proxy.com/https://api.github.com/'),
      'https://gh-proxy.com/https://api.github.com/',
    );
    expect(
      normalizeGitHubApiBaseUrl('https://mirror.example.com'),
      'https://mirror.example.com/',
    );
  });

  test('buildGitHubApiReleasesLatestUrl prefix and host mirror', () {
    expect(
      buildGitHubApiReleasesLatestUrl(
        owner: 'bilirec',
        repository: 'bilirec-mobile',
        apiBase: 'https://gh-proxy.com/https://api.github.com/',
      ),
      'https://gh-proxy.com/https://api.github.com/repos/bilirec/bilirec-mobile/releases/latest',
    );
    expect(
      buildGitHubApiReleasesLatestUrl(
        owner: 'bilirec',
        repository: 'bilirec-mobile',
        apiBase: 'https://mirror.example.com/',
      ),
      'https://mirror.example.com/repos/bilirec/bilirec-mobile/releases/latest',
    );
  });

  test('rewriteGitHubUrlForProxy', () {
    const asset =
        'https://api.github.com/repos/bilirec/bilirec-mobile/releases/assets/1';
    expect(
      rewriteGitHubUrlForProxy(
        asset,
        'https://gh-proxy.org/https://api.github.com/',
      ),
      'https://gh-proxy.org/https://api.github.com/repos/bilirec/bilirec-mobile/releases/assets/1',
    );
    expect(
      rewriteGitHubUrlForProxy(asset, 'https://mirror.example.com/'),
      'https://mirror.example.com/repos/bilirec/bilirec-mobile/releases/assets/1',
    );
    const web =
        'https://github.com/bilirec/bilirec-mobile/releases/download/v1/app.apk';
    expect(
      rewriteGitHubUrlForProxy(web, 'https://mirror.example.com/'),
      web,
    );
  });
}
