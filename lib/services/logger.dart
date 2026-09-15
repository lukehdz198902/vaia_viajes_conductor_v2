import 'dart:convert';

class Logger {
  static bool enabled = true;

  static void _log(String level, String tag, String message) {
    if (!enabled) return;
    final ts = DateTime.now().toIso8601String().split('.').first;
    // ignore: avoid_print
    print('[$ts][$level][$tag] $message');
  }

  static void i(String tag, String message) => _log('INFO', tag, message);
  static void w(String tag, String message) => _log('WARN', tag, message);
  static void e(String tag, String message) => _log('ERROR', tag, message);

  static void apiRequest(String method, String url, [Map<String, dynamic>? body]) {
    final b = body != null ? ' | body: ${json.encode(body)}' : '';
    i('API', '>> $method $url$b');
  }

  static void apiResponse(String method, String url, int statusCode, dynamic data) {
    final s = _truncate(data is String ? data : (data is Map || data is List ? json.encode(data) : data.toString()));
    i('API', '<< $method $url -> $statusCode | $s');
  }

  static void apiError(String method, String url, dynamic error) {
    e('API', '!! $method $url FAILED: $error');
  }

  static String _truncate(String s, [int max = 500]) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}... [${s.length - max} more chars]';
  }
}