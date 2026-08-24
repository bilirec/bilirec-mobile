import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:github_release_apk_updater/github_release_apk_updater.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bilirec/shared/browser_launcher.dart';
import 'package:bilirec/shared/debugger.dart';
import 'package:bilirec/shared/preferences.dart';

const String _ownerGithub = 'bilirec';
const String _repositoryGithub = 'bilirec-mobile';
const String _apiKeyName = 'bilirec-release';
const String _releasePageUrl =
    'https://github.com/$_ownerGithub/$_repositoryGithub/releases/latest';

class AppUpdateCandidate {
  const AppUpdateCandidate({
    required this.version,
    required this.releaseNote,
    required this.apkUrl,
    required this.releasePageUrl,
  });

  final String version;
  final String releaseNote;
  final String apkUrl;
  final String releasePageUrl;
}

enum AppUpdateExecutionResult { installLaunched, releasePageOpened, failed }

class AppUpdateService {
  AppUpdateService({
    GithubReleaseApkUpdater? updater,
    GithubApiService? apiService,
    ApkDownloaderService? apkDownloader,
    VersionComparator? versionComparator,
    Future<Directory> Function()? temporaryDirectoryProvider,
    Future<Directory?> Function()? externalStorageDirectoryProvider,
    Future<String> Function()? currentAppVersionProvider,
  })  : _updater = updater ?? GithubReleaseApkUpdater(),
        _apiService = apiService ?? GithubApiService(),
        _apkDownloader = apkDownloader ?? ApkDownloaderService(),
        _versionComparator = versionComparator ?? VersionComparator(),
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory,
        _externalStorageDirectoryProvider = externalStorageDirectoryProvider ??
            getExternalStorageDirectory,
        _currentAppVersionProvider = currentAppVersionProvider;

  final GithubReleaseApkUpdater _updater;
  final GithubApiService _apiService;
  final ApkDownloaderService _apkDownloader;
  final VersionComparator _versionComparator;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final Future<Directory?> Function() _externalStorageDirectoryProvider;
  final Future<String> Function()? _currentAppVersionProvider;

  static String normalizeVersionIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final withoutPrefix = trimmed.replaceFirst(RegExp(r'^[vV]\.?'), '');
    final coreVersion = withoutPrefix.split(RegExp(r'[-+]')).first;
    if (coreVersion.isEmpty) return '';

    return coreVersion
        .split('.')
        .map((part) => int.tryParse(part.trim())?.toString() ?? '0')
        .join('.');
  }

  static bool shouldSkipPromptForRelease({
    required String releaseVersion,
    required String? skippedVersion,
  }) {
    if (skippedVersion == null || skippedVersion.trim().isEmpty) {
      return false;
    }

    final normalizedRelease = normalizeVersionIdentifier(releaseVersion);
    final normalizedSkipped = normalizeVersionIdentifier(skippedVersion);
    return normalizedRelease.isNotEmpty &&
        normalizedRelease == normalizedSkipped;
  }

  static bool isApkFileName(String name) {
    return name.toLowerCase().endsWith('.apk');
  }

  static String updateApkFileNameForVersion(String version) {
    return 'bilirec-update-${normalizeVersionIdentifier(version)}.apk';
  }

  static bool _isVersionedUpdateApkFileName(String name) {
    final lower = name.toLowerCase();
    return lower.startsWith('bilirec-update-') && lower.endsWith('.apk');
  }

  Future<String> currentInstalledVersion() async {
    try {
      final versionProvider = _currentAppVersionProvider;
      final raw = versionProvider != null
          ? await versionProvider()
          : await _updater.getCurrentAppVersion();
      return normalizeVersionIdentifier(raw);
    } catch (e) {
      debugLog('app_update: failed to read current version: $e');
      return '';
    }
  }

  Future<bool> isFirstLaunchAfterUpdate() async {
    final currentVersion = await currentInstalledVersion();
    if (currentVersion.isEmpty) {
      return false;
    }

    final lastSeenRaw = await Preferences.getLastSeenInstalledVersion();
    if (lastSeenRaw == null || lastSeenRaw.trim().isEmpty) {
      return true;
    }

    return normalizeVersionIdentifier(lastSeenRaw) != currentVersion;
  }

  Future<void> acknowledgeInstalledVersion() async {
    final currentVersion = await currentInstalledVersion();
    if (currentVersion.isEmpty) {
      return;
    }
    await Preferences.setLastSeenInstalledVersion(currentVersion);
  }

  @visibleForTesting
  static Future<void> cleanupApkFilesInDirectory(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final fileName = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!isApkFileName(fileName)) {
        continue;
      }

      try {
        await entity.delete();
        debugLog('app_update: deleted apk ${entity.path}');
      } catch (e) {
        debugLog('app_update: failed to delete apk ${entity.path}: $e');
      }
    }
  }

  @visibleForTesting
  static Future<void> cleanupOtherVersionedUpdateApks(
    Directory directory, {
    required String keepFileName,
  }) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final fileName = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!_isVersionedUpdateApkFileName(fileName) || fileName == keepFileName) {
        continue;
      }

      try {
        await entity.delete();
        debugLog('app_update: deleted stale update apk ${entity.path}');
      } catch (e) {
        debugLog(
          'app_update: failed to delete stale update apk ${entity.path}: $e',
        );
      }
    }
  }

  Future<void> cleanupDownloadedApks() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await cleanupApkFilesInDirectory(await _temporaryDirectoryProvider());
    } catch (e) {
      debugLog('app_update: cleanup temp apk files failed: $e');
    }

    try {
      final externalDirectory = await _externalStorageDirectoryProvider();
      if (externalDirectory != null) {
        await cleanupApkFilesInDirectory(externalDirectory);
      }
    } catch (e) {
      debugLog('app_update: cleanup external apk files failed: $e');
    }
  }

  Future<AppUpdateCandidate?> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final supportedAbis = await _updater.getSupportedAbis();
      final release = await _apiService.getLatestGithubAPKRelease(
        ownerGithub: _ownerGithub,
        repositoryGithub: _repositoryGithub,
        apkKeyName: _apiKeyName,
        supportedAbis: supportedAbis,
      );
      if (release == null) {
        return null;
      }

      final latestVersion = normalizeVersionIdentifier(release.version);
      final currentVersion = await currentInstalledVersion();
      if (latestVersion.isEmpty || currentVersion.isEmpty) {
        debugLog(
          'app_update: empty version encountered (latest=$latestVersion, current=$currentVersion)',
        );
        return null;
      }

      debugLog(
          'app_update: latest version=$latestVersion, current version=$currentVersion');

      final hasNewVersion = _versionComparator.isNewerVersion(
        latestVersion,
        currentVersion,
      );
      if (!hasNewVersion) {
        await Preferences.setSkippedUpdateVersion(null);
        return null;
      }

      debugLog('app_update: new version available: $latestVersion');

      final skippedVersion = await Preferences.getSkippedUpdateVersion();
      if (shouldSkipPromptForRelease(
        releaseVersion: latestVersion,
        skippedVersion: skippedVersion,
      )) {
        debugLog('app_update: skipped dialog for version $latestVersion');
        return null;
      }

      if (skippedVersion != null && skippedVersion.isNotEmpty) {
        await Preferences.setSkippedUpdateVersion(null);
      }

      return AppUpdateCandidate(
        version: latestVersion,
        releaseNote: release.releaseNote.trim(),
        apkUrl: release.apkUrl,
        releasePageUrl: _releasePageUrl,
      );
    } catch (e) {
      debugLog('app_update: failed to check updates: $e');
      return null;
    }
  }

  Future<void> skipReminderForVersion(String version) async {
    final normalizedVersion = normalizeVersionIdentifier(version);
    await Preferences.setSkippedUpdateVersion(
      normalizedVersion.isEmpty ? null : normalizedVersion,
    );
  }

  Future<AppUpdateExecutionResult> performUpdateWithFallback(
    AppUpdateCandidate candidate, {
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    final downloadedAndInstalled = await _downloadAndInstall(
      candidate,
      onDownloadProgress: onDownloadProgress,
    );
    if (downloadedAndInstalled) {
      return AppUpdateExecutionResult.installLaunched;
    }

    final opened = await openReleasePage(candidate.releasePageUrl);
    if (!opened) {
      debugLog('app_update: failed to open release page fallback');
      return AppUpdateExecutionResult.failed;
    }
    return AppUpdateExecutionResult.releasePageOpened;
  }

  Future<bool> openReleasePage([String? releasePageUrl]) async {
    final target = (releasePageUrl == null || releasePageUrl.isEmpty)
        ? _releasePageUrl
        : releasePageUrl;
    return openUrlPreferChrome(Uri.parse(target));
  }

  Future<bool> _downloadAndInstall(
    AppUpdateCandidate candidate, {
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    try {
      final filePath = await downloadApkToInternalStorage(
            candidate.apkUrl,
            version: candidate.version,
            onDownloadProgress: onDownloadProgress,
          ) ??
          await _apkDownloader.downloadAPK(
            candidate.apkUrl,
            null,
            onDownloadProgress,
          );
      if (filePath == null || filePath.isEmpty) {
        debugLog('app_update: apk download failed');
        return false;
      }

      await _updater.installApk(filePath);
      return true;
    } catch (e) {
      debugLog('app_update: apk install failed: $e');
      return false;
    }
  }

  @visibleForTesting
  Future<String?> downloadApkToInternalStorage(
    String apkUrl, {
    required String version,
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    HttpClient? client;
    IOSink? sink;
    try {
      final normalizedVersion = normalizeVersionIdentifier(version);
      if (normalizedVersion.isEmpty) {
        debugLog('app_update: skip internal download for empty version');
        return null;
      }

      final targetDirectory = await _temporaryDirectoryProvider();
      final fileName = updateApkFileNameForVersion(normalizedVersion);
      final file = File('${targetDirectory.path}/$fileName');

      await cleanupOtherVersionedUpdateApks(
        targetDirectory,
        keepFileName: fileName,
      );

      if (await file.exists() && await file.length() > 0) {
        debugLog('app_update: reusing downloaded apk ${file.path}');
        return file.path;
      }

      client = HttpClient();
      final request = await client.getUrl(Uri.parse(apkUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugLog(
          'app_update: internal download failed with status ${response.statusCode}',
        );
        return null;
      }

      sink = file.openWrite();
      var received = 0;
      final total = response.contentLength;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onDownloadProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!await file.exists() || await file.length() == 0) {
        return null;
      }

      debugLog('app_update: downloaded apk to internal storage ${file.path}');
      return file.path;
    } catch (e) {
      debugLog('app_update: internal storage download failed: $e');
      return null;
    } finally {
      await sink?.close();
      client?.close(force: true);
    }
  }
}
