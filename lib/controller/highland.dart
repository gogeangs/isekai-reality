part of '../app_controller.dart';

/// 지금 하늘에 떠 있는 섬
class SkyIsland {
  const SkyIsland({
    required this.isle,
    required this.point,
    required this.until,
    required this.climbed,
    required this.cleared,
  });

  final Isle isle;
  final GeoPoint point;

  /// 이때 사라진다
  final DateTime until;

  /// 이번에 떠오른 섬에 올랐는지 (떠 있는 동안 깃털 없이 다시 도전)
  final bool climbed;

  /// 이번 섬의 수호자를 쓰러뜨렸는지 (그러면 섬이 문을 닫는다)
  final bool cleared;

  IsleInfo get info => HighlandRules.info(isle);
}

/// 폐허의 길에서 찾은 것
enum RuinsFind { chest, empty, feather }

class RuinsResult {
  const RuinsResult(this.find, {this.gold = 0, this.mats = const {}});

  final RuinsFind find;
  final int gold;
  final Map<MaterialId, int> mats;
}

/// 수호자 · 석상 병사를 쓰러뜨렸을 때 (결과 화면)
class SkyResult {
  const SkyResult({
    required this.won,
    this.firstKill = false,
    this.isle,
    this.mats = const {},
    this.exp = 0,
    this.titles = const [],
  });

  final bool won;
  final bool firstKill;
  final Isle? isle;
  final Map<MaterialId, int> mats;
  final int exp;

  /// 처음 쓰러뜨려 얻은 비문 자리 (isle 순서 = 1~5번 자리)
  int? get inscription => firstKill && isle != null ? isle!.index : null;
  final List<TitleId> titles;
}

/// 하이랜드 (묶음 50 #146): 하루 두 번 하늘에 떠오르는 섬 · 하늘 깃털 · 갈림길 · 수호자 다섯 · 비문
extension HighlandOps on AppController {
  HighlandState get highland => _highland;

  /// 하이랜드가 열렸는지 (2막 Lv.17)
  bool get highlandOpen =>
      _act2Ready &&
      !inTutorial &&
      player.level.level >= HighlandRules.openLevel;

  bool get _skyLonger =>
      gear.sets.abilities.contains(BossSetAbility.skyKnight);

  Set<Isle> get _skyBeaten => {
        for (final i in _highland.beaten) Isle.values[i],
      };

  /// 지금 하늘에 떠 있는 섬 (없으면 null). 처음 보는 칸이면 지금 자리 둘레로 정한다
  SkyIsland? get skyIsland {
    if (!highlandOpen) return null;
    final s = HighlandRules.slotAt(_clock(), longer: _skyLonger);
    if (s == null) return null;
    if (_highland.slot != s.slot) {
      // 내 자리를 알아야 둘레에 띄운다 (기본 자리에 띄우면 걸어갈 수 없다)
      final here = _lastFix?.point;
      if (here == null) return null;
      _raiseIsland(s.slot, s.evening, here);
    }
    final h = _highland;
    if (h.slot != s.slot || h.isle == null || h.lat == null || h.lng == null) {
      return null;
    }
    return SkyIsland(
      isle: Isle.values[h.isle!.clamp(0, 4)],
      point: GeoPoint(h.lat!, h.lng!),
      until: s.until,
      climbed: h.climbed,
      cleared: h.cleared,
    );
  }

  /// 새 칸의 섬을 띄운다 (자리는 바로, 저장은 뒤에서)
  void _raiseIsland(String slot, bool evening, GeoPoint anchor) {
    final h = _highland;
    final day = slot.substring(0, 10);
    final avoid = evening && h.amDay == day && h.amIsle != null
        ? Isle.values[h.amIsle!.clamp(0, 4)]
        : null;
    final isle = HighlandRules.pickIsle(
        slot: slot, first: h.firstIsle, beaten: _skyBeaten, avoid: avoid);
    final p = HighlandRules.spot(area,
        slot: slot,
        anchor: anchor,
        roads: roads,
        exclusions: exclusions,
        land: lands?.kindAt);
    _highland = h.copyWith(
      slot: slot,
      isle: isle.index,
      lat: p.lat,
      lng: p.lng,
      climbed: false,
      cleared: false,
      amDay: evening ? null : day,
      amIsle: evening ? null : isle.index,
    );
    unawaited(_saveHighland());
  }

  /// 섬까지 거리 (m)
  double? get skyDistance {
    final s = skyIsland;
    final f = _lastFix;
    if (s == null || f == null) return null;
    return s.point.distanceTo(f.point);
  }

  /// 걸어서 섬 아래에 닿았는지
  bool get atSkyIsland =>
      (skyDistance ?? double.infinity) <= HighlandRules.enterM;

  /// 묶음 81 #375: 걸어서 닿았거나 펫이 섬 아래에서 기다림
  bool get skyReachable => atSkyIsland || tripWaiting('sky');

  /// 남은 시간 (분, 올림)
  int get skyMinutesLeft {
    final s = skyIsland;
    if (s == null) return 0;
    return (s.until.difference(_clock()).inSeconds / 60).ceil().clamp(0, 999);
  }

  int get skyFeathers => player.materialCount(MaterialId.skyFeather);

  // ───────────── 첫 만남 (처음 하늘에 섬이 뜰 때 한 번, #124: 예전 Lv.17 이상도 같다)

  bool get highlandScenePending =>
      highlandOpen &&
      farewellDone &&
      !_highland.sceneSeen &&
      skyIsland != null;

  /// 첫 장면을 넘겼을 때: 첫 펫이 주운 하늘 깃털 하나 (처음 한 번)
  Future<void> markHighlandScene() => _serial(() async {
        if (_highland.sceneSeen) return;
        final give = !_highland.starter;
        _highland = _highland.copyWith(sceneSeen: true, starter: true);
        await _saveHighland();
        if (give) {
          await _grant(0, 0, {MaterialId.skyFeather: HighlandRules.starterFeathers});
        }
        _notify();
      });

  // ───────────── 하늘 깃털 (걸음 · 날개 달린 몬스터 · 폐허)

  /// 걸음으로 하늘 깃털 (하루 한도까지) · 다음 섬 알림
  Future<void> _highlandWalk() async {
    if (!highlandOpen) return;
    _scheduleSkyNotice();
    final today = player.today;
    if (today == null) return;
    final h = _highland;
    final day = today.dayKey;
    final got = h.featherDay == day ? h.featherGot : 0;
    final want =
        HighlandRules.feathersFor(today.steps, set2: gear.sets.skyFeather);
    if (want <= got) return;
    _highland = h.copyWith(featherDay: day, featherGot: want);
    await _saveHighland();
    await _grant(0, 0, {MaterialId.skyFeather: want - got});
    _notify();
  }

  /// 다음 섬이 떠오를 때 알림 (같은 때면 다시 예약하지 않음)
  void _scheduleSkyNotice() {
    final at = HighlandRules.nextRise(_clock());
    if (_skyNoticeAt == at) return;
    _skyNoticeAt = at;
    unawaited(notifier?.schedule(NotifyId.highland, at, '하늘에 섬이 떠올랐어!',
        '한 시간 동안만 머물러요. 걸어가거나 펫을 보내 보자.'));
  }

  /// 날개 달린 몬스터가 가끔 떨어뜨린다 (필드 전투 보상에 더함)
  void _wingFeather(MonsterId m, Map<MaterialId, int> mats) {
    if (!highlandOpen || !HighlandRules.winged.contains(m)) return;
    if (_random.nextDouble() >= HighlandRules.wingDrop) return;
    mats[MaterialId.skyFeather] = (mats[MaterialId.skyFeather] ?? 0) + 1;
  }

  // ───────────── 오르기

  /// 섬에 오를 수 있는지 (걸어서 닿았고, 처음이면 깃털이 있어야)
  bool get canClimb {
    final s = skyIsland;
    if (s == null || s.cleared || !skyReachable) return false;
    return s.climbed || skyFeathers >= 1;
  }

  /// 섬에 오른다. 처음 오를 때만 깃털 하나 (떠 있는 동안 다시 도전은 무료)
  Future<bool> climbIsland() => _serial(() async {
        final s = skyIsland;
        if (s == null || s.cleared || !skyReachable) return false;
        if (!s.climbed) {
          if (skyFeathers < 1) return false;
          final first = !_highland.climbedEver;
          final today = await _todayRecord();
          await _save(today.copyWith(
            spends: DailyRecord.addCounts(
                today.spends, {MaterialId.skyFeather.name: 1}),
            counters: first
                ? DailyRecord.addCounts(today.counters,
                    {TitleRules.skyCounter(HighlandRules.climbTitle): 1})
                : today.counters,
          ));
          _highland = _highland.copyWith(climbed: true, climbedEver: true);
          await _saveHighland();
        }
        _notify();
        return true;
      });

  /// 처음 섬에 올랐을 때 첫 펫 한마디 (한 번)
  String? takeFirstClimbLine() {
    if (!_highland.climbedEver || _highland.firstLine) return null;
    _highland = _highland.copyWith(firstLine: true);
    unawaited(_saveHighland());
    return HighlandRules.firstClimbLine;
  }

  bool get _onIsland {
    final s = skyIsland;
    return s != null && s.climbed && !s.cleared;
  }

  // ───────────── 갈림길: 폐허의 길

  Future<RuinsResult?> searchRuins() => _serial(() async {
        if (!_onIsland) return null;
        final r = _random.nextDouble();
        final RuinsResult res;
        if (r < HighlandRules.ruinsChest) {
          final gold = HighlandRules.chestGoldMin +
              _random.nextInt(
                  HighlandRules.chestGoldMax - HighlandRules.chestGoldMin + 1);
          res = RuinsResult(RuinsFind.chest,
              gold: gold, mats: const {MaterialId.skyStone: 1});
        } else if (r < HighlandRules.ruinsChest + HighlandRules.ruinsFeather) {
          res = const RuinsResult(RuinsFind.feather,
              mats: {MaterialId.skyFeather: 1});
        } else {
          res = const RuinsResult(RuinsFind.empty);
        }
        if (res.gold > 0 || res.mats.isNotEmpty) {
          await _grant(res.gold, 0, res.mats);
        }
        _notify();
        return res;
      });

  // ───────────── 갈림길: 석상의 길 · 수호자

  Battle? startSoldierBattle() {
    final s = skyIsland;
    if (!_onIsland || s == null || hp <= 0 || !canFightNow) return null;
    return _ashBattle(
        [HighlandRules.soldierFoe(s.isle, player.level.level)]);
  }

  Battle? startGuardianBattle() {
    final s = skyIsland;
    if (!_onIsland || s == null || hp <= 0 || !canFightNow) return null;
    return _ashBattle(
        [HighlandRules.guardianFoe(s.isle, player.level.level)]);
  }

  /// 석상 병사와 싸운 뒤: 이기면 하늘 돌 조각 조금
  Future<SkyResult> finishSoldierBattle(Battle battle) => _serial(() async {
        if (!battle.isOver) return const SkyResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        if (battle.phase != BattlePhase.cleared) {
          await _tripFought('sky'); // 묶음 81 #375: 지면 펫은 돌아오는 길
          await _defeated();
          _notify();
          return const SkyResult(won: false);
        }
        final n = HighlandRules.soldierStoneMin +
            _random.nextInt(
                HighlandRules.soldierStoneMax - HighlandRules.soldierStoneMin + 1);
        final today = await _todayRecord();
        await _save(today.copyWith(
          purifiedMonsterIds: _addMonsters(today, [MonsterId.stoneSoldier]),
          counters: DailyRecord.addCounts(today.counters, {'skySoldier': 1}),
        ));
        final mats = {MaterialId.skyStone: n};
        await _grant(0, 0, mats);
        _notify();
        return SkyResult(won: true, isle: skyIsland?.isle, mats: mats);
      });

  /// 수호자와 싸운 뒤: 이기면 하늘 돌 조각 · 그 섬 결정, 처음이면 비문 · 경험치. 섬은 문을 닫는다
  Future<SkyResult> finishGuardianBattle(Battle battle) => _serial(() async {
        final i = HighlandRules.ofGuardian(battle.floors.first.monster);
        if (i == null || !battle.isOver) return const SkyResult(won: false);
        await _tripFought('sky'); // 묶음 81 #375: 수호자와 싸우면(이기든 지든) 펫은 돌아오는 길
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        if (battle.phase != BattlePhase.cleared) {
          await _defeated();
          _notify();
          return SkyResult(won: false, isle: i.id);
        }
        final first = !_highland.beaten.contains(i.id.index);
        final stones = HighlandRules.guardianStoneMin +
            _random.nextInt(HighlandRules.guardianStoneMax -
                HighlandRules.guardianStoneMin +
                1);
        final crystals = first
            ? HighlandRules.firstCrystals
            : (_random.nextDouble() < HighlandRules.crystalChance ? 1 : 0);
        final mats = {
          MaterialId.skyStone: stones,
          if (crystals > 0) i.crystal: crystals,
        };
        final beaten = first
            ? [..._highland.beaten, i.id.index]
            : _highland.beaten;
        final titles = <TitleId>[
          if (first && beaten.length >= 5) ...[
            HighlandRules.guardiansTitle,
            HighlandRules.witnessTitle,
          ],
        ];
        final exp = first ? HighlandRules.guardianExp : 0;
        final today = await _todayRecord();
        await _save(today.copyWith(
          purifiedMonsterIds: _addMonsters(today, [i.guardian]),
          counters: DailyRecord.addCounts(today.counters, {
            'skyGuardian': 1,
            for (final t in titles) TitleRules.skyCounter(t): 1,
          }),
          gains: exp > 0
              ? DailyRecord.addCounts(today.gains, {'exp': exp})
              : today.gains,
        ));
        await _grant(0, 0, mats);
        _highland = _highland.copyWith(beaten: beaten, cleared: true);
        await _saveHighland();
        if (first) await gainMastery(Mastery.combat, MasteryRules.dungeonClear);
        _notify();
        return SkyResult(
          won: true,
          firstKill: first,
          isle: i.id,
          mats: mats,
          exp: exp,
          titles: titles,
        );
      });

  // ───────────── 비문 (기록 탭)

  /// 비문 다섯 자리 (얻은 자리만 글, 나머지는 null)
  List<String?> get skyInscriptions => [
        for (final i in HighlandRules.isles)
          _highland.beaten.contains(i.id.index) ? i.inscription : null,
      ];

  Future<void> _saveHighland() =>
      store.saveJson(AppController._highlandKey, _highland.toJson());
}
