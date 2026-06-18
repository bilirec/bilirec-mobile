import 'dart:convert';
import 'dart:io';
import 'dart:math';

const defaultBackendBaseUrl = 'http://127.0.0.1:8080';
const defaultBroadcastsEndpoint =
    'https://workers.vrp.moe/laplace/ranking?type=danmakus';

class TaskQueue {
  TaskQueue({
    required this.taskId,
    required this.inputPath,
    this.outputPath,
    this.convertTaskId,
    this.deleteSource,
    this.inputFileSize,
    this.inputFormat,
    this.outputFormat,
    this.provider,
  });

  final String taskId;
  final String inputPath;
  final String? outputPath;
  final String? convertTaskId;
  final bool? deleteSource;
  final int? inputFileSize;
  final String? inputFormat;
  final String? outputFormat;
  final String? provider;

  factory TaskQueue.fromJson(Map<String, dynamic> json) {
    return TaskQueue(
      taskId: json['task_id'] as String? ?? '',
      inputPath: json['input_path'] as String? ?? '',
      outputPath: json['output_path'] as String?,
      convertTaskId: json['convert_task_id'] as String?,
      deleteSource: json['delete_source'] as bool?,
      inputFileSize: json['input_file_size'] as int?,
      inputFormat: json['input_format'] as String?,
      outputFormat: json['output_format'] as String?,
      provider: json['provider'] as String?,
    );
  }
}

class ApiCallResult {
  const ApiCallResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  String bodyPreview({int maxLength = 500}) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }
}

Future<Map<String, dynamic>> readJsonResponse(
    HttpClientResponse response) async {
  final body = await response.transform(utf8.decoder).join();
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return <String, dynamic>{'data': decoded};
}

Future<List<TaskQueue>> listConvertTasks({
  String baseUrl = defaultBackendBaseUrl,
  String? bearerToken,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('$baseUrl/convert/tasks'))
        .timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'list convert tasks failed: status=${response.statusCode}, body=$body',
      );
    }

    final decoded = body.trim().isEmpty ? const [] : jsonDecode(body);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((item) => TaskQueue.fromJson(item))
        .toList(growable: false);
  } finally {
    client.close(force: true);
  }
}

Future<ApiCallResult> enqueueConvertTask(
  String filePath, {
  bool deleteOriginal = false,
  String baseUrl = defaultBackendBaseUrl,
  String? bearerToken,
}) async {
  final client = HttpClient();
  try {
    final encodedPath = Uri.encodeComponent(filePath);
    final uri = Uri.parse('$baseUrl/convert/tasks/$encodedPath')
        .replace(queryParameters: {'delete': deleteOriginal.toString()});

    final request = await client.postUrl(uri).timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }

    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    return ApiCallResult(statusCode: response.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}

Future<int> cancelConvertTask(
  String taskId, {
  String baseUrl = defaultBackendBaseUrl,
  String? bearerToken,
}) async {
  final client = HttpClient();
  try {
    final encodedTaskId = Uri.encodeComponent(taskId);
    final request = await client
        .deleteUrl(Uri.parse('$baseUrl/convert/tasks/$encodedTaskId'))
        .timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (bearerToken != null && bearerToken.trim().isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
    }

    final response = await request.close().timeout(const Duration(seconds: 12));
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<int> subscribeRoom(
  int roomId, {
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final request =
        await client.postUrl(Uri.parse('$baseUrl/room/$roomId')).timeout(
              const Duration(seconds: 5),
            );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<int> updateRoomConfig(
  int roomId, {
  String baseUrl = defaultBackendBaseUrl,
  Map<String, dynamic> payload = const {
    'auto_record': false,
    'notify': true,
    'record_duration_minutes': 120,
  },
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .putUrl(Uri.parse('$baseUrl/room/$roomId/config'))
        .timeout(const Duration(seconds: 5));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<List<int>> fetchLiveBroadcastRoomIDs({
  String endpoint = defaultBroadcastsEndpoint,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 6));
    final response = await request.close().timeout(const Duration(seconds: 90));

    if (response.statusCode != HttpStatus.ok) {
      throw StateError('broadcast API status=${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    final decoded = body.trim().isEmpty ? const [] : jsonDecode(body);
    if (decoded is! List) {
      throw StateError('broadcast API response is not a list');
    }

    final ids = <int>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      if (item['isDeleted'] == true) continue;
      final raw = item['roomid'] ?? item['roomId'];
      final id = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      if (id != null && id > 0) {
        ids.add(id);
      }
    }

    return ids.toList(growable: false);
  } finally {
    client.close(force: true);
  }
}

List<int> pickDistinctRoomIDs(
  List<int> pool,
  int count, {
  Random? random,
}) {
  if (pool.length < count) {
    throw StateError('live room ids less than $count');
  }

  final shuffled = List<int>.from(pool);
  shuffled.shuffle(random ?? Random(DateTime.now().microsecondsSinceEpoch));
  return shuffled.take(count).toList(growable: false);
}

Future<ApiCallResult> startRecording(
  int roomId, {
  required int durationMinutes,
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      '$baseUrl/record/$roomId/start?duration_minutes=$durationMinutes',
    );
    final request =
        await client.postUrl(uri).timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();
    return ApiCallResult(statusCode: response.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}

Future<void> stopRecording(
  int roomId, {
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .postUrl(Uri.parse('$baseUrl/record/$roomId/stop'))
        .timeout(const Duration(seconds: 6));
    final response = await request.close().timeout(const Duration(seconds: 10));
    await response.drain<void>();
  } finally {
    client.close(force: true);
  }
}

Future<Map<int, String>> fetchRecordStatuses(
  List<int> roomIds, {
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .postUrl(Uri.parse('$baseUrl/record/statuses'))
        .timeout(const Duration(seconds: 6));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode({'roomIDs': roomIds}));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final payload = await readJsonResponse(response);

    final result = <int, String>{};
    payload.forEach((key, value) {
      final id = int.tryParse(key.toString());
      if (id != null) {
        result[id] = value.toString();
      }
    });
    return result;
  } finally {
    client.close(force: true);
  }
}

Future<Map<int, Map<String, dynamic>>> fetchRecordStats(
  List<int> roomIds, {
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .postUrl(Uri.parse('$baseUrl/record/stats'))
        .timeout(const Duration(seconds: 6));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode({'roomIDs': roomIds}));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final payload = await readJsonResponse(response);

    final result = <int, Map<String, dynamic>>{};
    payload.forEach((key, value) {
      final id = int.tryParse(key.toString());
      if (id != null && value is Map<String, dynamic>) {
        result[id] = value;
      }
    });
    return result;
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, dynamic>>> browseFiles({
  required String search,
  String baseUrl = defaultBackendBaseUrl,
}) async {
  return browseFilesAtPath(
    browsePath: '',
    search: search,
    baseUrl: baseUrl,
  );
}

Future<List<Map<String, dynamic>>> browseFilesAtPath({
  required String browsePath,
  String? search,
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  final normalizedPath = browsePath.trim();
  final encodedPath = normalizedPath.isEmpty
      ? ''
      : normalizedPath
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .map(Uri.encodeComponent)
          .join('/');

  final query = <String, String>{
    'offset': '0',
    'limit': '200',
    if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
  };

  final uris = <Uri>[
    Uri.parse('$baseUrl/files/browse/$encodedPath').replace(
      queryParameters: query,
    ),
    Uri.parse('$baseUrl/files/browse/$encodedPath/').replace(
      queryParameters: query,
    ),
  ];

  try {
    for (final uri in uris) {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 6));
      final response =
          await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        continue;
      }

      final payload = await readJsonResponse(response);
      final items = payload['items'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map((e) => e)
            .toList(growable: false);
      }
    }
  } finally {
    client.close(force: true);
  }

  return const [];
}

Future<Map<String, dynamic>> fetchRoomInfo(
  int roomId, {
  String baseUrl = defaultBackendBaseUrl,
}) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(Uri.parse('$baseUrl/room/$roomId/info'))
        .timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    final payload = await readJsonResponse(response);
    return payload;
  } finally {
    client.close(force: true);
  }
}
