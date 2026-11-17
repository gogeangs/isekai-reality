part of '../app_controller.dart';

/// 묶음 55 #245: 로그인 결과 (화면이 다음에 할 일)
enum CloudLogin {
  /// 서버에 기록이 없어 휴대폰 기록을 올림
  uploaded,

  /// 휴대폰이 새것이라 서버 기록으로 이어 감 (앱이 다시 켜짐)
  restored,

  /// 둘 다 있음 → 고르기 화면
  choose,

  /// 로그인을 그만둠 · 실패 · 인터넷 없음 · 준비 안 됨
  cancelled,
  failed,
  offline,
  unavailable,
}

/// 백업 결과
enum CloudBackup { ok, unchanged, offline, failed, notReady }

/// 두 기록 고르기 화면에 보일 요약
class RecordSummary {
  const RecordSummary({required this.level, required this.lastDay});
  final int level;

  /// yyyy-mm-dd (기록이 없으면 빈 글자)
  final String lastDay;
}

/// 이 휴대폰의 로그인 · 백업 상태 (백업에는 안 들어감)
class CloudState {
  const CloudState({
    this.uid,
    this.provider,
    this.label,
    this.lastBackup,
    this.hash,
    this.choosing = false,
    this.keptAt,
    this.cancelledDelete = false,
  });

  final String? uid;
  final LoginProvider? provider;
  final String? label;
  final DateTime? lastBackup;

  /// 마지막으로 올린 기록 (같으면 다시 안 올림)
  final int? hash;

  /// 로그인했지만 두 기록 중 아직 안 고름 (그동안 백업 안 함)
  final bool choosing;

  /// 고르지 않은 기록을 서버에 보관한 때 (7일 뒤 지움)
  final DateTime? keptAt;

  /// 이번 로그인에서 계정 삭제 요청을 취소했는지 (안내 한 번)
  final bool cancelledDelete;

  bool get signedIn => uid != null;

  CloudState copyWith({
    DateTime? lastBackup,
    int? hash,
    bool? choosing,
    DateTime? keptAt,
    bool? cancelledDelete,
  }) =>
      CloudState(
        uid: uid,
        provider: provider,
        label: label,
        lastBackup: lastBackup ?? this.lastBackup,
        hash: hash ?? this.hash,
        choosing: choosing ?? this.choosing,
        keptAt: keptAt ?? this.keptAt,
        cancelledDelete: cancelledDelete ?? this.cancelledDelete,
      );

  Map<String, dynamic> toJson() => {
        if (uid != null) 'uid': uid,
        if (provider != null) 'provider': provider!.name,
        if (label != null) 'label': label,
        if (lastBackup != null) 'last': lastBackup!.toUtc().toIso8601String(),
        if (hash != null) 'hash': hash,
        if (choosing) 'choosing': true,
        if (keptAt != null) 'keptAt': keptAt!.toUtc().toIso8601String(),
        if (cancelledDelete) 'cancelledDelete': true,
      };

  static CloudState fromJson(Map<String, dynamic> j) => CloudState(
        uid: j['uid'] as String?,
        provider: LoginProvider.values.asNameMap()[j['provider']],
        label: j['label'] as String?,
        lastBackup: DateTime.tryParse('${j['last'] ?? ''}'),
        hash: (j['hash'] as num?)?.toInt(),
        choosing: j['choosing'] == true,
        keptAt: DateTime.tryParse('${j['keptAt'] ?? ''}'),
        cancelledDelete: j['cancelledDelete'] == true,
      );
}

/// 서버 시간 차이 (휴대폰 시계 + 차이 = 서버 시간). 하루 규칙은 모두 이 시계로
class ServerClock {
  ServerClock({DateTime Function()? device}) : _device = device ?? DateTime.now;

  final DateTime Function() _device;
  int offsetMs = 0;

  /// 서버 시간을 한 번이라도 받았는지
  bool synced = false;

  DateTime now() =>
      offsetMs == 0 ? _device() : _device().add(Duration(milliseconds: offsetMs));

  /// 서버 시간을 받았을 때. 2초 안 차이는 무시
  void apply(DateTime server) {
    final d = server.difference(_device()).inMilliseconds;
    offsetMs = d.abs() < 2000 ? 0 : d;
    synced = true;
  }
}

extension CloudOps on AppController {
  static const _sideKey = 'cloud';
  static const _clockKey = 'clockOffset';

  /// 로그인 · 백업을 쓸 수 있는 빌드인지 (Firebase 설정값이 있음)
  bool get cloudAvailable => cloudAuth != null && backupServer != null;

  CloudState get cloud => _cloud;
  bool get cloudBusy => _cloudBusy;

  /// 이 휴대폰에서 쓸 수 있는 로그인 (iPhone: Apple · Google, Android: Google)
  List<LoginProvider> get loginProviders => cloudAuth?.providers ?? const [];

  Future<void> _loadCloud() async {
    try {
      final raw = await store.loadSide(_sideKey);
      if (raw != null) {
        _cloud = CloudState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
      final off = int.tryParse(await store.loadSide(_clockKey) ?? '');
      if (off != null && serverClock != null && !serverClock!.synced) {
        serverClock!.offsetMs = off;
      }
    } catch (_) {}
    // 로그인 앱이 따로 로그아웃됐으면 (예: 다른 기기에서 계정 삭제) 이 휴대폰도 로그아웃으로
    final a = cloudAuth;
    if (a != null && _cloud.signedIn && a.current != null && a.current!.uid != _cloud.uid) {
      _cloud = const CloudState();
      await _saveCloud();
    }
  }

  Future<void> _saveCloud() async {
    try {
      await store.saveSide(_sideKey, _cloud.signedIn ? jsonEncode(_cloud.toJson()) : null);
    } catch (_) {}
  }

  /// 서버 시간을 받아 하루 규칙 시계를 맞춘다 (인터넷이 없으면 마지막으로 받은 차이 그대로)
  Future<void> refreshServerTime() async {
    final s = backupServer, clock = serverClock;
    if (s == null || clock == null) return;
    final t = await s.serverTime();
    if (t == null) return;
    final before = _clock();
    clock.apply(t);
    try {
      await store.saveSide(_clockKey, '${clock.offsetMs}');
    } catch (_) {}
    if (DailyRecord.dayKeyOf(before) != DailyRecord.dayKeyOf(_clock())) _notify();
  }

  RecordSummary get phoneSummary => RecordSummary(
        level: player.level.level,
        lastDay: _history.isEmpty ? '' : _history.last.dayKey,
      );

  /// 휴대폰에 이어 갈 기록이 있는지 (각성 전 · 빈 기록이면 없음)
  bool get _phoneHasRecord => !_needsAwakening && _history.isNotEmpty;

  /// 로그인. 서버에 기록이 없으면 올리고, 휴대폰이 새것이면 서버 기록으로, 둘 다 있으면 고르기
  Future<CloudLogin> signInCloud(LoginProvider p) async {
    final a = cloudAuth, s = backupServer;
    if (a == null || s == null) return CloudLogin.unavailable;
    if (_cloudBusy) return CloudLogin.cancelled;
    _cloudBusy = true;
    _notify();
    try {
      final (status, user) = await a.signIn(p);
      if (status == LoginStatus.cancelled) return CloudLogin.cancelled;
      if (status != LoginStatus.ok || user == null) return CloudLogin.failed;
      final token = await a.idToken();
      if (token == null) {
        await a.signOut();
        return CloudLogin.failed;
      }
      BackupMeta? meta;
      try {
        meta = await s.meta(user.uid, token);
      } on BackupOffline {
        await a.signOut();
        return CloudLogin.offline;
      }
      var cancelled = false;
      if (meta?.deleteAt case final at?) {
        if (at.isAfter(_clock().toUtc())) {
          // 7일 안에 다시 로그인 → 삭제 취소
          await s.cancelDelete(user.uid, token);
          cancelled = true;
        } else {
          // 7일이 지났는데 아직 남아 있으면 지우고 새로 시작
          await s.wipe(user.uid, token);
          meta = null;
        }
      }
      _cloud = CloudState(
          uid: user.uid, provider: user.provider, label: user.label, cancelledDelete: cancelled);
      final server = meta?.current;
      if (server == null) {
        await _saveCloud();
        final r = await _upload(force: true);
        return r == CloudBackup.ok ? CloudLogin.uploaded : CloudLogin.offline;
      }
      if (!_phoneHasRecord) {
        // 휴대폰을 바꾼 사람: 서버 기록으로 이어서
        await _saveCloud();
        await _restore(server, token);
        return CloudLogin.restored;
      }
      _serverChoice = server;
      _cloud = _cloud.copyWith(choosing: true);
      await _saveCloud();
      return CloudLogin.choose;
    } catch (e) {
      debugPrint('로그인 처리 실패: $e');
      return CloudLogin.failed;
    } finally {
      _cloudBusy = false;
      _notify();
    }
  }

  /// 고르기 화면에 보일 서버 기록 (앱을 껐다 켰으면 다시 읽음)
  Future<RecordSummary?> serverSummary() async {
    final info = _serverChoice ?? await _readServer();
    _serverChoice = info;
    return info == null ? null : RecordSummary(level: info.level, lastDay: info.lastDay);
  }

  Future<BackupInfo?> _readServer() async {
    final a = cloudAuth, s = backupServer, uid = _cloud.uid;
    if (a == null || s == null || uid == null) return null;
    final token = await a.idToken();
    if (token == null) return null;
    try {
      return (await s.meta(uid, token))?.current;
    } catch (_) {
      return null;
    }
  }

  /// 두 기록 중 하나를 고른다. 고르지 않은 쪽은 서버에 7일 보관
  Future<bool> chooseRecord({required bool useServer}) async {
    final a = cloudAuth, s = backupServer, uid = _cloud.uid;
    if (a == null || s == null || uid == null || _cloudBusy) return false;
    _cloudBusy = true;
    _notify();
    try {
      final token = await a.idToken();
      final server = _serverChoice ?? await _readServer();
      if (token == null || server == null) return false;
      final now = _clock().toUtc();
      if (useServer) {
        final phone = phoneSummary;
        await s.keep(uid, token, await store.exportAll(),
            level: phone.level, lastDay: phone.lastDay, from: 'phone');
        _cloud = _cloud.copyWith(choosing: false, keptAt: now);
        await _saveCloud();
        await _restore(server, token);
      } else {
        await s.keep(uid, token, await s.download(uid, token, server),
            level: server.level, lastDay: server.lastDay, from: 'server');
        _cloud = _cloud.copyWith(choosing: false, keptAt: now);
        await _saveCloud();
        await _upload(force: true);
      }
      _serverChoice = null;
      return true;
    } catch (e) {
      debugPrint('기록 고르기 실패: $e');
      return false;
    } finally {
      _cloudBusy = false;
      _notify();
    }
  }

  /// 서버 기록으로 바꾸고 앱을 처음부터 다시 읽는다
  Future<void> _restore(BackupInfo info, String token) async {
    final data = await backupServer!.download(_cloud.uid!, token, info);
    await store.importAll(data);
    _cloud = _cloud.copyWith(lastBackup: info.updatedAt ?? _clock(), hash: _hashOf(data));
    await _saveCloud();
    final restart = onRestored;
    if (restart != null) {
      await restart();
    } else {
      await init();
    }
  }

  static int _hashOf(Map<String, Object> s) => jsonEncode(s).hashCode;

  Future<CloudBackup> _upload({bool force = false}) async {
    final a = cloudAuth, s = backupServer, uid = _cloud.uid;
    if (a == null || s == null || uid == null || _cloud.choosing) return CloudBackup.notReady;
    try {
      final token = await a.idToken();
      if (token == null) return CloudBackup.offline;
      final snap = await store.exportAll();
      final h = _hashOf(snap);
      if (!force && h == _cloud.hash) return CloudBackup.unchanged;
      final sum = phoneSummary;
      final info = await s.upload(uid, token, snap, level: sum.level, lastDay: sum.lastDay);
      _cloud = _cloud.copyWith(lastBackup: info.updatedAt ?? _clock(), hash: h);
      await _saveCloud();
      // 7일 지난 보관본 정리
      final kept = _cloud.keptAt;
      if (kept != null && _clock().toUtc().difference(kept).inDays >= 7) {
        await s.dropKept(uid, token);
        _cloud = CloudState(
          uid: _cloud.uid,
          provider: _cloud.provider,
          label: _cloud.label,
          lastBackup: _cloud.lastBackup,
          hash: _cloud.hash,
        );
        await _saveCloud();
      }
      return CloudBackup.ok;
    } on BackupOffline {
      return CloudBackup.offline;
    } catch (e) {
      debugPrint('백업 실패: $e');
      return CloudBackup.failed;
    }
  }

  /// 설정 「지금 백업」
  Future<CloudBackup> backupNow() async {
    if (_cloudBusy) return CloudBackup.notReady;
    _cloudBusy = true;
    _notify();
    try {
      return await _upload(force: true);
    } finally {
      _cloudBusy = false;
      _notify();
    }
  }

  /// 조용한 백업 (앱을 닫을 때 · 10분마다). 바뀐 게 없으면 안 올림
  Future<void> autoBackup() async {
    await refreshServerTime();
    if (!_cloud.signedIn || _cloud.choosing || _cloudBusy || !_ready) return;
    _cloudBusy = true;
    try {
      await _upload();
    } finally {
      _cloudBusy = false;
    }
    _notify();
  }

  /// 로그아웃 (그 전에 한 번 올려 둠). 휴대폰 기록은 그대로
  Future<void> signOutCloud() async {
    if (_cloud.signedIn && !_cloud.choosing) await _upload();
    await cloudAuth?.signOut();
    _cloud = const CloudState();
    _serverChoice = null;
    await _saveCloud();
    _notify();
  }

  /// 계정 삭제 요청: 7일 뒤 서버 기록을 지움 (그 안에 다시 로그인하면 취소).
  /// [keepPhone] 이 false 면 휴대폰 기록도 지우고 처음부터
  Future<bool> requestAccountDeletion({required bool keepPhone}) async {
    final a = cloudAuth, s = backupServer, uid = _cloud.uid;
    if (a == null || s == null || uid == null) return false;
    _cloudBusy = true;
    _notify();
    try {
      final token = await a.idToken();
      if (token == null) return false;
      await s.markDelete(uid, token, _clock().toUtc().add(accountDeleteWait));
      await a.revoke();
      await a.signOut();
      _cloud = const CloudState();
      _serverChoice = null;
      await _saveCloud();
      if (!keepPhone) await resetAll();
      return true;
    } catch (e) {
      debugPrint('계정 삭제 요청 실패: $e');
      return false;
    } finally {
      _cloudBusy = false;
      _notify();
    }
  }

  /// 삭제 취소 안내를 보였으면
  void markDeleteCancelSeen() {
    if (!_cloud.cancelledDelete) return;
    _cloud = _cloud.copyWith(cancelledDelete: false);
    unawaited(_saveCloud());
    _notify();
  }

  /// 계정 삭제 · 고르지 않은 기록 보관 기간
  static const Duration accountDeleteWait = Duration(days: 7);
}
