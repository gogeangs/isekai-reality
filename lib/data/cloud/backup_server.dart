import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'cloud_config.dart';

/// 서버에 있는 기록 하나의 요약 (두 기록 고르기 · 설정에 보임)
class BackupInfo {
  const BackupInfo({
    required this.gen,
    required this.parts,
    required this.level,
    required this.lastDay,
    this.updatedAt,
    this.from,
    this.keptAt,
  });

  /// 조각 묶음 이름 · 조각 수
  final String gen;
  final int parts;

  /// 기록의 레벨 · 마지막으로 걸은 날 (yyyy-mm-dd)
  final int level;
  final String lastDay;
  final DateTime? updatedAt;

  /// 보관본: 어디서 왔는지('phone' · 'server') · 보관한 때
  final String? from;
  final DateTime? keptAt;
}

/// 서버의 내 기록 문서 (users/{uid})
class BackupMeta {
  const BackupMeta({this.current, this.kept, this.deleteAt});

  final BackupInfo? current;

  /// 처음 로그인 때 고르지 않은 쪽 (7일 보관)
  final BackupInfo? kept;

  /// 계정 삭제 요청: 이때 지움 (그 전에 다시 로그인하면 취소)
  final DateTime? deleteAt;
}

/// 서버에 닿지 못함 (인터넷 없음 등)
class BackupOffline implements Exception {
  const BackupOffline([this.message = '']);
  final String message;
  @override
  String toString() => 'BackupOffline($message)';
}

/// 묶음 55 #245: 기록 백업 서버. 실제는 Firestore(REST), 테스트는 [FakeBackupServer]
abstract class BackupServer {
  /// 서버 시간 (못 닿으면 null)
  Future<DateTime?> serverTime();

  Future<BackupMeta?> meta(String uid, String token);
  Future<Map<String, Object>> download(String uid, String token, BackupInfo info);

  /// 기록을 올린다. 예전 조각은 지운다 (보관본은 그대로)
  Future<BackupInfo> upload(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, String? device});

  /// 고르지 않은 기록을 보관 (예전 보관본은 지움)
  Future<void> keep(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, required String from});

  /// 7일 지난 보관본을 지운다
  Future<void> dropKept(String uid, String token);

  Future<void> markDelete(String uid, String token, DateTime at);
  Future<void> cancelDelete(String uid, String token);

  /// 내 기록을 모두 지운다 (삭제 요청 뒤 7일이 지나 다시 로그인했을 때)
  Future<void> wipe(String uid, String token);
}

/// 스냅숏 ↔ 글자 (gzip + base64)
class SnapshotCodec {
  SnapshotCodec._();

  /// Firestore 문서 하나 1MiB 안에 들게 조각 크기
  static const int chunk = 700000;

  static String encode(Map<String, Object> s) =>
      base64.encode(gzip.encode(utf8.encode(jsonEncode(s))));

  static Map<String, Object> decode(String text) {
    final raw = jsonDecode(utf8.decode(gzip.decode(base64.decode(text)))) as Map;
    return {
      for (final e in raw.entries)
        if (e.value is String)
          '${e.key}': e.value as String
        else if (e.value is List)
          '${e.key}': [for (final x in e.value as List) '$x'],
    };
  }

  static List<String> split(String text) => [
        for (var i = 0; i < text.length; i += chunk)
          text.substring(i, math.min(text.length, i + chunk)),
        if (text.isEmpty) '',
      ];
}

/// Firestore REST (Cloud Functions 없이, 내 uid 문서만 읽고 쓰는 규칙)
class FirestoreBackupServer implements BackupServer {
  FirestoreBackupServer({HttpClient? client})
      : _http = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  final HttpClient _http;
  static const _timeout = Duration(seconds: 20);

  String get _docs => CloudConfig.documents;
  String get _root => _docs.substring(_docs.indexOf('projects/'));

  Future<(int, Map<String, dynamic>?)> _call(String method, String url,
      {String? token, Object? body}) async {
    try {
      final req = await _http.openUrl(method, Uri.parse(url)).timeout(_timeout);
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(_timeout);
      final text = await res.transform(utf8.decoder).join().timeout(_timeout);
      _lastDate = res.headers.date;
      Map<String, dynamic>? json;
      if (text.isNotEmpty) {
        try {
          final j = jsonDecode(text);
          if (j is Map) json = Map<String, dynamic>.from(j);
        } catch (_) {}
      }
      return (res.statusCode, json);
    } on TimeoutException {
      throw const BackupOffline('timeout');
    } on SocketException catch (e) {
      throw BackupOffline(e.message);
    } on HttpException catch (e) {
      throw BackupOffline(e.message);
    } on HandshakeException catch (e) {
      throw BackupOffline(e.message);
    }
  }

  DateTime? _lastDate;

  void _ok(int code, Map<String, dynamic>? j) {
    if (code >= 200 && code < 300) return;
    if (code >= 500 || code == 0) throw BackupOffline('http $code');
    throw HttpException('http $code ${j?['error']?['status'] ?? ''}');
  }

  @override
  Future<DateTime?> serverTime() async {
    try {
      // 서버가 답할 때 붙이는 시간 (주소는 아무 곳이나: 404 여도 시간은 옴)
      await _call('GET', 'https://firestore.googleapis.com/');
      return _lastDate?.toUtc();
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _str(String v) => {'stringValue': v};
  static Map<String, dynamic> _int(int v) => {'integerValue': '$v'};
  static Map<String, dynamic> _time(DateTime v) =>
      {'timestampValue': v.toUtc().toIso8601String()};

  static String? _s(Map<String, dynamic>? f, String k) =>
      (f?[k] as Map?)?['stringValue'] as String?;
  static int _i(Map<String, dynamic>? f, String k) =>
      int.tryParse('${(f?[k] as Map?)?['integerValue'] ?? ''}') ?? 0;
  static DateTime? _t(Map<String, dynamic>? f, String k) {
    final v = (f?[k] as Map?)?['timestampValue'] as String?;
    return v == null ? null : DateTime.tryParse(v);
  }

  static BackupInfo? _info(Map<String, dynamic>? f) {
    final gen = _s(f, 'gen');
    if (gen == null) return null;
    return BackupInfo(
      gen: gen,
      parts: _i(f, 'parts'),
      level: _i(f, 'level'),
      lastDay: _s(f, 'lastDay') ?? '',
      updatedAt: _t(f, 'updatedAt'),
      from: _s(f, 'from'),
      keptAt: _t(f, 'keptAt'),
    );
  }

  Map<String, dynamic> _infoFields(BackupInfo i) => {
        'gen': _str(i.gen),
        'parts': _int(i.parts),
        'level': _int(i.level),
        'lastDay': _str(i.lastDay),
        if (i.from != null) 'from': _str(i.from!),
        if (i.keptAt != null) 'keptAt': _time(i.keptAt!),
      };

  String _user(String uid) => '$_root/users/$uid';
  String _part(String uid, String gen, int i) => '$_root/users/$uid/parts/${gen}_$i';

  @override
  Future<BackupMeta?> meta(String uid, String token) async {
    final (code, j) = await _call('GET', '$_docs/users/$uid', token: token);
    if (code == 404) return null;
    _ok(code, j);
    final f = (j?['fields'] as Map?)?.cast<String, dynamic>();
    final kept = ((f?['kept'] as Map?)?['mapValue'] as Map?)?['fields'] as Map?;
    return BackupMeta(
      current: _info(f),
      kept: _info(kept?.cast<String, dynamic>()),
      deleteAt: _t(f, 'deleteAt'),
    );
  }

  @override
  Future<Map<String, Object>> download(String uid, String token, BackupInfo info) async {
    final buf = StringBuffer();
    for (var i = 0; i < info.parts; i++) {
      final (code, j) =
          await _call('GET', '$_docs/users/$uid/parts/${info.gen}_$i', token: token);
      _ok(code, j);
      buf.write(_s((j?['fields'] as Map?)?.cast<String, dynamic>(), 'data') ?? '');
    }
    return SnapshotCodec.decode(buf.toString());
  }

  Future<DateTime?> _commit(String token, List<Map<String, dynamic>> writes) async {
    if (writes.isEmpty) return null;
    final (code, j) =
        await _call('POST', '$_docs:commit', token: token, body: {'writes': writes});
    _ok(code, j);
    final t = j?['commitTime'] as String?;
    return t == null ? null : DateTime.tryParse(t);
  }

  static String _newGen() =>
      '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(1 << 20).toRadixString(36)}';

  /// 조각을 올린다 (한 번에 6MB 아래로 나눠서)
  Future<(String, int)> _writeParts(String uid, String token, Map<String, Object> s) async {
    final gen = _newGen();
    final parts = SnapshotCodec.split(SnapshotCodec.encode(s));
    var batch = <Map<String, dynamic>>[];
    var size = 0;
    for (final (i, p) in parts.indexed) {
      batch.add({
        'update': {
          'name': _part(uid, gen, i),
          'fields': {'data': _str(p), 'gen': _str(gen)},
        },
      });
      size += p.length;
      if (size > 6000000) {
        await _commit(token, batch);
        batch = [];
        size = 0;
      }
    }
    await _commit(token, batch);
    return (gen, parts.length);
  }

  List<Map<String, dynamic>> _deleteParts(String uid, BackupInfo? i) => [
        if (i != null)
          for (var k = 0; k < i.parts; k++) {'delete': _part(uid, i.gen, k)},
      ];

  @override
  Future<BackupInfo> upload(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, String? device}) async {
    BackupMeta? old;
    try {
      old = await meta(uid, token);
    } on HttpException {
      old = null;
    }
    final (gen, n) = await _writeParts(uid, token, snapshot);
    final info = BackupInfo(gen: gen, parts: n, level: level, lastDay: lastDay);
    final at = await _commit(token, [
      {
        'update': {
          'name': _user(uid),
          'fields': {..._infoFields(info), if (device != null) 'device': _str(device)},
        },
        'updateMask': {
          'fieldPaths': ['gen', 'parts', 'level', 'lastDay', if (device != null) 'device'],
        },
        'updateTransforms': [
          {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
          // 운영정책: 이 계정에 로그인한 휴대폰 (무작위 기기 ID, 같은 휴대폰 계정끼리 거래 · 파티 막기용)
          if (device != null)
            {
              'fieldPath': 'devices',
              'appendMissingElements': {
                'values': [_str(device)],
              },
            },
        ],
      },
      if (old?.current case final c? when c.gen != old?.kept?.gen) ..._deleteParts(uid, c),
    ]);
    return BackupInfo(gen: gen, parts: n, level: level, lastDay: lastDay, updatedAt: at);
  }

  @override
  Future<void> keep(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, required String from}) async {
    final old = await meta(uid, token);
    final (gen, n) = await _writeParts(uid, token, snapshot);
    final info = BackupInfo(
        gen: gen, parts: n, level: level, lastDay: lastDay, from: from,
        keptAt: DateTime.now().toUtc());
    await _commit(token, [
      {
        'update': {
          'name': _user(uid),
          'fields': {
            'kept': {'mapValue': {'fields': _infoFields(info)}},
          },
        },
        'updateMask': {'fieldPaths': ['kept']},
      },
      if (old?.kept case final k? when k.gen != old?.current?.gen) ..._deleteParts(uid, k),
    ]);
  }

  @override
  Future<void> dropKept(String uid, String token) async {
    final m = await meta(uid, token);
    final k = m?.kept;
    if (k == null) return;
    await _commit(token, [
      {
        'update': {'name': _user(uid), 'fields': <String, dynamic>{}},
        'updateMask': {'fieldPaths': ['kept']},
      },
      if (k.gen != m?.current?.gen) ..._deleteParts(uid, k),
    ]);
  }

  Future<List<String>> _partNames(String uid, String token) async {
    final names = <String>[];
    String? page;
    do {
      final q = 'pageSize=300&mask.fieldPaths=gen${page == null ? '' : '&pageToken=$page'}';
      final (code, j) = await _call('GET', '$_docs/users/$uid/parts?$q', token: token);
      if (code == 404) break;
      _ok(code, j);
      for (final d in (j?['documents'] as List?) ?? const []) {
        names.add((d as Map)['name'] as String);
      }
      page = j?['nextPageToken'] as String?;
    } while (page != null);
    return names;
  }

  /// 삭제 시간 표시 (expireAt 은 Firestore TTL 이 그때 스스로 지우게 하는 칸)
  Future<void> _stamp(String uid, String token, DateTime? at) async {
    final names = await _partNames(uid, token);
    final f = at == null ? <String, dynamic>{} : {'expireAt': _time(at)};
    final writes = <Map<String, dynamic>>[
      {
        'update': {
          'name': _user(uid),
          'fields': at == null ? <String, dynamic>{} : {'deleteAt': _time(at), 'expireAt': _time(at)},
        },
        'updateMask': {'fieldPaths': ['deleteAt', 'expireAt']},
      },
      for (final n in names)
        {
          'update': {'name': n, 'fields': f},
          'updateMask': {'fieldPaths': ['expireAt']},
        },
    ];
    for (var i = 0; i < writes.length; i += 400) {
      await _commit(token, writes.sublist(i, math.min(writes.length, i + 400)));
    }
  }

  @override
  Future<void> markDelete(String uid, String token, DateTime at) => _stamp(uid, token, at);

  @override
  Future<void> cancelDelete(String uid, String token) => _stamp(uid, token, null);

  @override
  Future<void> wipe(String uid, String token) async {
    final names = await _partNames(uid, token);
    final writes = [
      for (final n in names) {'delete': n},
      {'delete': _user(uid)},
    ];
    for (var i = 0; i < writes.length; i += 400) {
      await _commit(token, writes.sublist(i, math.min(writes.length, i + 400)));
    }
  }
}

/// 테스트용 서버 (메모리)
class FakeBackupServer implements BackupServer {
  final Map<String, BackupMeta> metas = {};
  final Map<String, Map<String, Object>> data = {};
  bool offline = false;
  DateTime? time;
  int uploads = 0;
  int _gen = 0;

  /// 계정마다 백업한 휴대폰 (기기 ID)
  final Map<String, Set<String>> devices = {};

  void _check() {
    if (offline) throw const BackupOffline('offline');
  }

  @override
  Future<DateTime?> serverTime() async => offline ? null : time;

  @override
  Future<BackupMeta?> meta(String uid, String token) async {
    _check();
    return metas[uid];
  }

  @override
  Future<Map<String, Object>> download(String uid, String token, BackupInfo info) async {
    _check();
    return SnapshotCodec.decode(SnapshotCodec.encode(data[info.gen]!));
  }

  @override
  Future<BackupInfo> upload(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, String? device}) async {
    _check();
    uploads++;
    if (device != null) (devices[uid] ??= {}).add(device);
    final g = 'g${_gen++}';
    data[g] = SnapshotCodec.decode(SnapshotCodec.encode(snapshot));
    final info = BackupInfo(
        gen: g, parts: 1, level: level, lastDay: lastDay, updatedAt: time ?? DateTime.now());
    final m = metas[uid];
    metas[uid] = BackupMeta(current: info, kept: m?.kept, deleteAt: m?.deleteAt);
    return info;
  }

  @override
  Future<void> keep(String uid, String token, Map<String, Object> snapshot,
      {required int level, required String lastDay, required String from}) async {
    _check();
    final g = 'k${_gen++}';
    data[g] = snapshot;
    final m = metas[uid];
    metas[uid] = BackupMeta(
      current: m?.current,
      deleteAt: m?.deleteAt,
      kept: BackupInfo(
          gen: g, parts: 1, level: level, lastDay: lastDay, from: from,
          keptAt: time ?? DateTime.now()),
    );
  }

  @override
  Future<void> dropKept(String uid, String token) async {
    _check();
    final m = metas[uid];
    if (m == null) return;
    metas[uid] = BackupMeta(current: m.current, deleteAt: m.deleteAt);
  }

  @override
  Future<void> markDelete(String uid, String token, DateTime at) async {
    _check();
    final m = metas[uid];
    metas[uid] = BackupMeta(current: m?.current, kept: m?.kept, deleteAt: at);
  }

  @override
  Future<void> cancelDelete(String uid, String token) async {
    _check();
    final m = metas[uid];
    if (m == null) return;
    metas[uid] = BackupMeta(current: m.current, kept: m.kept);
  }

  @override
  Future<void> wipe(String uid, String token) async {
    _check();
    metas.remove(uid);
  }
}
