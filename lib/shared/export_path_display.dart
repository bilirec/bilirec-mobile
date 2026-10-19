String formatExportPathForDisplay(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  var displayPath = trimmed;
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.scheme == 'content') {
    displayPath = displayPathFromContentUri(uri);
  }

  return ellipsizeMiddle(displayPath, maxLength: 56);
}

String displayPathFromContentUri(Uri uri) {
  final segments = uri.pathSegments;
  final documentIndex = segments.indexOf('document');
  if (documentIndex >= 0 && documentIndex + 1 < segments.length) {
    final documentId = Uri.decodeComponent(segments[documentIndex + 1]);
    final colonIndex = documentId.indexOf(':');
    if (colonIndex >= 0 && colonIndex + 1 < documentId.length) {
      return documentId.substring(colonIndex + 1);
    }
    return documentId;
  }

  if (segments.isNotEmpty) {
    return Uri.decodeComponent(segments.last);
  }

  return uri.toString().replaceFirst('content://', '');
}

String ellipsizeMiddle(String text, {required int maxLength}) {
  if (text.length <= maxLength) {
    return text;
  }

  const marker = '...';
  final headLength = (maxLength - marker.length) ~/ 2;
  final tailLength = maxLength - marker.length - headLength;
  return '${text.substring(0, headLength)}$marker${text.substring(text.length - tailLength)}';
}

bool isPermissionLikeStorageFailure(Object error) {
  final lower = '$error'.toLowerCase();
  return lower.contains('operation not permitted') ||
      lower.contains('permission denied') ||
      lower.contains('eacces') ||
      lower.contains('errno = 1') ||
      lower.contains('errno = 13');
}

class ExportTargetNotWritableException implements Exception {
  const ExportTargetNotWritableException();
}
