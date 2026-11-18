part of '../app_controller.dart';

/// 문의 보내기 결과
enum InquirySend { ok, tooMany, offline, bad }

/// 문의 (묶음 56 #248): 설정 → 문의. 로그인 안 해도 보냄(그 휴대폰 설치 번호로 답을 받음).
/// 답은 게임 안 우편 「문의에 답이 왔어요」 (+ 보상). 비밀번호 · 위치는 보내지 않는다.
extension InquiryOps on AppController {
  static const int perDay = 3;

  /// 오늘 보낸 문의 수 (이 휴대폰)
  Future<int> _inquiriesToday() async {
    final raw = await store.loadSide('inquiryDay');
    final day = DailyRecord.dayKeyOf(_clock());
    if (raw == null || !raw.startsWith('$day:')) return 0;
    return int.tryParse(raw.substring(day.length + 1)) ?? 0;
  }

  /// 계정 번호 (짧은 코드, 로그인 전엔 앱 설치 번호)
  Future<String> accountCode() async {
    final uid = _cloud.uid;
    if (uid != null && uid.isNotEmpty) return uid.substring(0, math.min(8, uid.length)).toUpperCase();
    return 'I-${(await deviceId()).substring(0, 8).toUpperCase()}';
  }

  /// 문의를 보낸다. [photo] 는 화면 사진 한 장 (JPEG, 이미 줄인 것)
  Future<InquirySend> sendInquiry({
    required String kind,
    required String text,
    List<int>? photo,
    String? email,
    String model = '',
  }) async {
    final api = arcaApi;
    if (api == null) return InquirySend.offline;
    if (await _inquiriesToday() >= perDay) return InquirySend.tooMany;
    String? token;
    try {
      if (_cloud.signedIn) token = await cloudAuth?.idToken();
    } catch (_) {}
    try {
      await api.post('/inquiry', {
        'kind': kind,
        'text': text.trim(),
        if (photo != null) 'photo': base64.encode(photo),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'install': await deviceId(),
        'appVersion': appVersionLabel,
        'model': model,
      }, token: token);
    } on ArcaApiError catch (e) {
      if (e.code == 'too_many') return InquirySend.tooMany;
      if (e.code == 'offline') return InquirySend.offline;
      return InquirySend.bad;
    } catch (_) {
      return InquirySend.offline;
    }
    final day = DailyRecord.dayKeyOf(_clock());
    await store.saveSide('inquiryDay', '$day:${await _inquiriesToday() + 1}');
    return InquirySend.ok;
  }

  /// 답 우편 받기 (앱을 열 때 · 돌아올 때). 받은 답 수
  Future<int> checkInquiryInbox() async {
    final api = arcaApi;
    if (api == null || !_ready) return 0;
    String? token;
    try {
      if (_cloud.signedIn) token = await cloudAuth?.idToken();
    } catch (_) {}
    try {
      final j = await api.post('/inbox', {'install': await deviceId()}, token: token);
      var n = 0;
      for (final m in (j['msgs'] as List?) ?? const []) {
        if (m is! Map) continue;
        final r = ((m['reward'] as Map?) ?? const {}).cast<String, dynamic>();
        // 묶음 58: 거래소(바르칸) · 심층 순위(하르트) 우편도 같은 길로. 장비는 이 휴대폰 번호를 새로 붙임
        final equips = <EquipItem>[];
        for (final e in (m['equips'] as List?) ?? const []) {
          if (e is! Map) continue;
          final it = EquipItem.fromJson(Map<String, dynamic>.from(e));
          if (it == null) continue;
          final a = _armory;
          await _saveArmory(a.copyWith(nextId: a.nextId + 1));
          equips.add(EquipItem(
            uid: 'eq${a.nextId}',
            base: it.base,
            grade: it.grade,
            enhance: it.enhance,
            durability: it.durability,
            extras: it.extras,
            materialsUsed: it.materialsUsed,
            enhanceManaSpent: it.enhanceManaSpent,
            appearance: it.appearance,
            element: it.element,
            elementLevel: it.elementLevel,
          ));
        }
        final fresh = await _sendMail(MailItem(
          id: 'inq_${m['id']}',
          kind: MailKind.reward,
          from: '${m['from'] ?? '여명의 탑 운영실'}',
          title: '${m['title'] ?? '문의에 답이 왔어요'}',
          body: '${m['body'] ?? ''}',
          equips: equips,
          gifts: {
            for (final e in r.entries)
              if (e.value is num && (e.value as num) > 0) e.key: (e.value as num).toInt(),
          },
          sentAt: _clock(),
          expiresAt: _clock().add(const Duration(days: 30)),
        ));
        // 묶음 59: 운영 · 길드 우편이 하는 일 (이름 바꾸기 · 되돌린 거래 거두기 · 칭호) — 처음 받을 때 한 번
        if (fresh && m['op'] is Map) await _applyOp((m['op'] as Map).cast<String, dynamic>());
        n++;
      }
      if (n > 0) _notify();
      return n;
    } catch (_) {
      return 0;
    }
  }

  /// 묶음 57: 서버에서 바뀐 금칙어 목록을 받는다 (앱을 켤 때 한 번)
  Future<void> refreshBannedWords() async {
    final api = arcaApi;
    if (api == null || _wordsFetched) return;
    _wordsFetched = true;
    try {
      final j = await api.post('/words', const {});
      final t = j['text'];
      if (t is String && t.length > 10) NameRules.load(t);
    } catch (_) {}
  }

  /// 묶음 59: 서버 우편의 일 — rename(운영자 이름 바꾸기) · take(되돌린 거래: 남은 만큼만 거둠) · title(레이드 칭호)
  Future<void> _applyOp(Map<String, dynamic> op) async {
    if (op['rename'] is Map) {
      final r = (op['rename'] as Map).cast<String, dynamic>();
      final id = r['id'] as String?;
      switch (r['target']) {
        case 'awakened':
          await updateProfile(_profile.copyWith(name: '각성자'));
        case 'pet':
          for (final p in _pets.pets) {
            if (id == null || p.uid == id) {
              await _savePets(_pets.replace(p.copyWith(name: p.info.name)));
              if (id != null) break;
            }
          }
        case 'ally':
          final a = id == null ? null : _act3.ally(id);
          if (a != null && !a.isStory) {
            _act3 = _act3.replaceAlly(a.copyWith(name: '동료'));
            await _saveAct3();
          }
      }
    }
    if (op['take'] is Map) {
      final t = (op['take'] as Map).cast<String, dynamic>();
      await _serial(() async {
        final today = await _todayRecord();
        final spends = <String, int>{};
        final counters = <String, int>{};
        final gold = math.min(player.gold, (t['gold'] as num?)?.toInt() ?? 0);
        if (gold > 0) spends[Wallet.gold] = gold;
        for (final e in ((t['mats'] as Map?) ?? const {}).entries) {
          final m = Materials.byName('${e.key}');
          if (m != null) {
            final n = math.min(player.materialCount(m), (e.value as num).toInt());
            if (n > 0) spends[m.name] = n;
          }
        }
        for (final e in ((t['items'] as Map?) ?? const {}).entries) {
          final it = ShopItem.values.where((i) => i.name == '${e.key}').firstOrNull;
          if (it != null) {
            final n = math.min(bagCount(it), (e.value as num).toInt());
            if (n > 0) counters[TownRules.dropKey(it)] = n;
          }
        }
        if (spends.isNotEmpty || counters.isNotEmpty) {
          await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, spends),
            counters: DailyRecord.addCounts(today.counters, counters),
          ));
        }
        for (final e in ((t['alcs'] as Map?) ?? const {}).entries) {
          final n = math.min(_alc.count('${e.key}'), (e.value as num).toInt());
          if (n > 0) await _saveAlc(_alc.add('${e.key}', -n));
        }
        final eggs = (t['eggs'] as num?)?.toInt() ?? 0;
        if (eggs > 0) {
          var left = eggs;
          await _savePets(_pets.copyWith(eggs: [
            for (final e in _pets.eggs)
              if (left > 0 && e.incubatedAt == null && left-- > 0) ...[] else e,
          ]));
        }
        if (t['equip'] is Map) {
          final q = (t['equip'] as Map).cast<String, dynamic>();
          final hit = _armory.items.where((i) =>
              !_armory.isWorn(i) &&
              i.base.name == q['base'] &&
              (q['grade'] == null || i.grade.name == q['grade']) &&
              (q['enhance'] == null || i.enhance == (q['enhance'] as num).toInt())).firstOrNull;
          if (hit != null) {
            await _saveArmory(_armory.copyWith(items: [for (final i in _armory.items) if (i.uid != hit.uid) i]));
          }
        }
      });
    }
    if (op['title'] is String) {
      final g = GuildRules.boss(op['title'] as String);
      if (g != null) {
        final k = TitleRules.skyCounter(g.title);
        if (!_history.any((d) => (d.counters[k] ?? 0) > 0)) {
          final today = await _todayRecord();
          await _save(today.copyWith(counters: DailyRecord.addCounts(today.counters, {k: 1})));
        }
      }
    }
    _notify();
  }

  // ───────────── 묶음 59: 공지 · 내 제재 상태

  List<({String id, String title, String body, DateTime from})> get notices => _notices;

  /// 아직 닫지 않은 가장 최근 공지 (홈 위 띠)
  ({String id, String title, String body, DateTime from})? get noticeBanner {
    for (final n in _notices) {
      if (!_noticeSeen.contains(n.id)) return n;
    }
    return null;
  }

  Future<void> dismissNotice(String id) async {
    _noticeSeen = {..._noticeSeen, id};
    await store.saveSide('noticeSeen', _noticeSeen.join(','));
    _notify();
  }

  Future<void> refreshNotices() async {
    final api = arcaApi;
    if (api == null || !_ready) return;
    try {
      _noticeSeen = {...((await store.loadSide('noticeSeen')) ?? '').split(',').where((x) => x.isNotEmpty)};
      final j = await api.post('/notices', const {});
      _notices = [
        for (final n in (j['items'] as List?) ?? const [])
          if (n is Map)
            (
              id: '${n['id']}',
              title: '${n['title'] ?? ''}',
              body: '${n['body'] ?? ''}',
              from: DateTime.fromMillisecondsSinceEpoch(((n['from'] as num?) ?? 0).toInt()),
            ),
      ];
      _notify();
    } catch (_) {}
  }

  /// 로그인 정지(3단계 이상) 중이면 그 까닭 한 줄 (아니면 null)
  String? get suspendedLine => _suspended;

  /// 내 제재 상태를 묻는다 (로그인했을 때). 로그인 정지면 로그인을 풀고 안내
  Future<void> refreshMyStatus() async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) return;
    try {
      final token = await a.idToken();
      if (token == null) return;
      final j = await api.post('/status', const {}, token: token);
      final lv = (j['level'] as num?)?.toInt() ?? 0;
      if (lv >= 3) {
        final until = j['until'] as String?;
        _suspended = '운영정책에 따라 로그인이 정지됐어요${until == null ? '' : ' (${until.substring(0, 10)}까지)'}. '
            '설정 → 문의에서 「제재 이의 제기」를 보낼 수 있어요.';
        await signOutCloud();
      } else {
        _suspended = null;
      }
      _notify();
    } catch (_) {}
  }
}
