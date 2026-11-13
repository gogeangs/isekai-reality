part of '../app_controller.dart';

/// 설정·불씨 색 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension SettingsOps on AppController {

  // ───────────────────────────────────────────── 불씨 색 (11-11 묶음 13: 날씨 기능은 뺐다. 기기 시간만)

  /// 불씨 빛 색 (낮 황금, 밤 보라)
  BulssiMood get bulssiMood => BulssiMoods.of(now: _clock());
  int get renameCost => _profile.renames == 0 ? 0 : AppController.renameGold;

  /// 이미 쓰는 이름인지 (11-11 #72): 마을 사람·정령·펫 이름과 겹치면 안 된다.
  /// (다른 모험가와의 중복 확인은 서버가 생기면 #49에서 더한다)
  bool nameTaken(String name) {
    final n = name.trim();
    if (n.isEmpty) return false;
    return {
      MailRules.hart,
      MailRules.mina,
      MailRules.dorgun,
      MailRules.eliel,
      _profile.spiritName,
      for (final p in _pets.pets) p.name,
    }.contains(n);
  }

  /// 내 이름을 바꾼다. 빈 이름·같은 이름이면 그대로, 금화가 모자라면 false.
  Future<bool> renameHero(String name) async {
    final n = name.trim();
    if (n.isEmpty || n == _profile.name || nameTaken(n)) return false;
    final cost = renameCost;
    if (player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    await updateProfile(
        _profile.copyWith(name: n, renames: _profile.renames + 1));
    return true;
  }

  // 정령 이름·종류는 각성 때 정하면 바꿀 수 없다 (11-11 #53)

  /// 테스트 결과 모으기용 하루별 기록 (CSV). 위치 좌표·이름은 넣지 않는다.
  String exportRecordsCsv() {
    final p = player;
    final b = StringBuffer(
        '날짜,걸음,목표,던전,던전클리어,필드몬스터,새장소,다시방문,새안개,휴식,경험치,레벨\n');
    var total = 0;
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      total += p.dailyExp[i].total;
      b.writeln([
        r.dayKey,
        r.steps,
        r.stepGoal,
        r.dungeonRuns.length,
        r.dungeonRuns.where((x) => x.cleared).length,
        r.fieldMonstersPurified,
        r.newPlacesVisited,
        r.placesRevisited,
        r.newCellsRevealed,
        r.restsCompleted,
        p.dailyExp[i].total,
        LevelRules.fromTotalExp(total).level,
      ].join(','));
    }
    b.writeln('# 칭호 ${p.titles.length}개, '
        '도감 ${purifiedEver.length}종');
    return b.toString();
  }

  /// 데이터 동의 철회: 기기에 저장한 모든 기록을 지우고 처음(각성)으로 돌아간다.
  /// 건강 앱·위치 권한 자체는 휴대폰 설정에서 끈다.
  Future<void> resetAll() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await store.clearAll();
    _history = [];
    _lastFix = null;
    _lastDiscovery = null;
    _vitals = const Vitals();
    _board = const BoardState();
    _armory = const Armory();
    _alloc = const StatAlloc();
    _profile = const PlayerProfile(name: '각성자');
    _needsAwakening = true;
    _ageBlocked = false;
    _notify();
  }

  Future<void> updateProfile(PlayerProfile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    _notify();
  }
}
