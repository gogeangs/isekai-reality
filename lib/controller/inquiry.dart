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
        await _sendMail(MailItem(
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
}
