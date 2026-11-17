import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 묶음 56: 아르카 서버(Cloud Functions 「api」) — 파티 · 함께 있어요 · 문의 · 답 우편.
/// 파티는 로그인 토큰이 있어야 하고, 문의 · 답 우편은 없어도 된다(그 휴대폰 설치 번호로).
abstract class ArcaApi {
  /// [path] 예: '/party/state'. 실패하면 [ArcaApiError]
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token});
}

class ArcaApiError implements Exception {
  const ArcaApiError(this.code, {this.status = 0});

  /// 서버가 준 오류 이름 ('full' · 'no_ticket' …) · 인터넷 문제면 'offline'
  final String code;
  final int status;

  @override
  String toString() => 'ArcaApiError($code, $status)';
}

class HttpArcaApi implements ArcaApi {
  HttpArcaApi({String? base, HttpClient? client})
      : base = base ?? defaultBase,
        _http = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  /// 서버 주소 (빌드 때 --dart-define=ARCA_API 로 바꿀 수 있음)
  static const String defaultBase = String.fromEnvironment('ARCA_API',
      defaultValue: 'https://api-ujbfnvvalq-du.a.run.app');

  final String base;
  final HttpClient _http;

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {String? token}) async {
    try {
      final req = await _http.postUrl(Uri.parse('$base$path')).timeout(const Duration(seconds: 15));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      final j = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      final map = j is Map ? j.cast<String, dynamic>() : <String, dynamic>{};
      if (res.statusCode >= 400) {
        throw ArcaApiError('${map['error'] ?? 'server'}', status: res.statusCode);
      }
      return map;
    } on ArcaApiError {
      rethrow;
    } on SocketException {
      throw const ArcaApiError('offline');
    } on TimeoutException {
      throw const ArcaApiError('offline');
    } on HandshakeException {
      throw const ArcaApiError('offline');
    } on FormatException {
      throw const ArcaApiError('server');
    }
  }
}
