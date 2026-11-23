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

/// 묶음 83: 구름 한 칸을 걷었을 때
class SkyStep {
  const SkyStep({required this.cell, required this.kind, this.mats = const {}, this.hint = 0});

  final int cell;
  final SkyCell kind;
  final Map<MaterialId, int> mats;

  /// 빈 칸이면 둘레에 숨은 유물 조각 수
  final int hint;
}

/// 묶음 83: 이번 오르기 결과 (「○층까지 올랐어요 · 하늘 결정 ○ · 하늘 돌 ○ · 유물 조각 ○」)
class SkyClimbSummary {
  const SkyClimbSummary({required this.floor, this.crystals = 0, this.stones = 0, this.shards = 0});

  factory SkyClimbSummary.of(SkyClimb c) => SkyClimbSummary(
      floor: c.floor, crystals: c.crystals, stones: c.stones, shards: c.shards);

  final int floor;
  final int crystals;
  final int stones;
  final int shards;
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
    this.climb,
  });

  /// 묶음 83: 수호자 전 오르기에서 얻은 것 (결과 창 합계)
  final SkyClimbSummary? climb;

  final bool won;
  final bool firstKill;
  final Isle? isle;
  final Map<MaterialId, int> mats;
  final int exp;

  /// 처음 쓰러뜨려 얻은 비문 자리 (isle 순서 = 1~5번 자리)
  int? get inscription => firstKill && isle != null ? isle!.index : null;
  final List<TitleId> titles;
}

/// 하이랜드 (묶음 50 #146): 하루 두 번 하늘에 떠오르는 섬 · 하늘 깃털 · 구름 걷기(묶음 83) · 수호자 다섯 · 비문
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

  // ───────────── 오르기 (묶음 83 #389: 쿼터뷰 구름 걷기)

  /// 섬에 오를 수 있는지 (걸어서 닿았거나 펫이 기다림 · 깃털 하나 · 이미 오르는 중이면 이어서)
  bool get canClimb {
    final s = skyIsland;
    if (s == null || s.cleared || !skyReachable) return false;
    return skyClimb != null || skyFeathers >= 1;
  }

  /// 지금 하고 있는 구름 걷기 (이 섬에서 오른 것만. 섬이 바뀌었으면 null)
  SkyClimb? get skyClimb {
    final c = _highland.climb;
    final s = skyIsland;
    if (c == null || s == null || s.cleared || c.slot != _highland.slot) return null;
    return c;
  }

  /// 지금 층의 판
  SkyBoard? get skyBoard {
    final c = skyClimb;
    if (c == null) return null;
    return _boardCache(c.seed, c.floor);
  }

  SkyBoard _boardCache(int seed, int floor) {
    final k = '$seed|$floor';
    if (_skyBoardKey != k || _skyBoardMemo == null) {
      _skyBoardMemo = SkyBoard.generate(seed, floor);
      _skyBoardKey = k;
    }
    return _skyBoardMemo!;
  }

  /// 섬에 오른다: 깃털 하나로 새 판 (오를 때마다 섞임). 오르는 중이면 그대로 이어서
  Future<bool> climbIsland() => _serial(() async {
        final s = skyIsland;
        if (s == null || s.cleared || !skyReachable) return false;
        if (skyClimb != null) return true;
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
        final seed = _random.nextInt(0x7fffffff);
        final board = _boardCache(seed, 1);
        _highland = _highland.copyWith(
          climbed: true,
          climbedEver: true,
          climb: () => SkyClimb(
            slot: _highland.slot!,
            seed: seed,
            floor: 1,
            wind: SkyWalkRules.floor(1).wind,
            opened: [board.entrance],
            hero: board.entrance,
          ),
        );
        await _saveHighland();
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

  /// 처음 오를 때 안내: 첫 카드를 보여 줄 때 본 것으로 저장 (#383)
  bool get skyGuideSeen => _highland.guideSeen;
  Future<void> markSkyGuide() async {
    if (_highland.guideSeen) return;
    _highland = _highland.copyWith(guideSeen: true);
    await _saveHighland();
  }

  /// 구름 한 칸을 걷는다 (바람 1). 걷을 수 없으면 null
  Future<SkyStep?> revealSkyCell(int cell) => _serial(() async {
        final c = skyClimb;
        final b = skyBoard;
        if (c == null || b == null || c.soldier != null || c.awake) return null;
        final opened = c.opened.toSet();
        if (!b.canReveal(cell, opened) || c.wind < SkyWalkRules.windPerCell) {
          return null;
        }
        final kind = b.at(cell)!;
        var wind = c.wind - SkyWalkRules.windPerCell;
        var shards = c.shards, crystals = c.crystals, stones = c.stones;
        final mats = <MaterialId, int>{};
        final isle = skyIsland!.isle;
        switch (kind) {
          case SkyCell.crystal:
            mats[SkyWalkRules.crystalOf(isle)] = 1;
            crystals++;
          case SkyCell.stone:
            mats[MaterialId.skyStone] = 1;
            stones++;
          case SkyCell.spring:
            wind += SkyWalkRules.springWind;
          case SkyCell.shard:
            shards = math.min(SkyWalkRules.floorCount, shards + 1);
          default:
        }
        _highland = _highland.copyWith(
          climb: () => c.copyWith(
            wind: wind,
            opened: [...c.opened, cell],
            hero: cell,
            shards: shards,
            crystals: crystals,
            stones: stones,
            soldier: kind == SkyCell.soldier ? () => cell : null,
          ),
        );
        await _saveHighland();
        if (mats.isNotEmpty) await _grant(0, 0, mats);
        _notify();
        return SkyStep(cell: cell, kind: kind, mats: mats,
            hint: kind == SkyCell.empty ? b.hint(cell, {...opened, cell}) : 0);
      });

  /// 계단(제단)을 찾았는지
  bool get skyGoalFound {
    final c = skyClimb, b = skyBoard;
    return c != null && b != null && c.opened.contains(b.goal);
  }

  /// 「위층으로」 (계단을 찾았고 1 · 2층)
  bool get canClimbUp {
    final c = skyClimb;
    return c != null && c.floor < SkyWalkRules.floorCount && skyGoalFound && c.soldier == null;
  }

  /// 「제단에서 수호자 깨우기」 (꼭대기 · 제단 · 조각 셋)
  bool get canWakeGuardian {
    final c = skyClimb;
    return c != null &&
        c.floor == SkyWalkRules.floorCount &&
        skyGoalFound &&
        c.shards >= SkyWalkRules.floorCount &&
        c.soldier == null &&
        hp > 0;
  }

  /// 바람이 다했고 갈 곳(계단 · 제단)이 없으면 끝
  bool get skyStuck {
    final c = skyClimb;
    if (c == null || c.soldier != null || c.awake) return false;
    if (c.wind >= SkyWalkRules.windPerCell) return false;
    if (c.floor < SkyWalkRules.floorCount) return !skyGoalFound;
    return !canWakeGuardian;
  }

  /// 위층으로 (남은 바람은 그대로 + 그 층 바람)
  Future<bool> climbUp() => _serial(() async {
        final c = skyClimb;
        if (c == null || !canClimbUp) return false;
        final f = c.floor + 1;
        final b = _boardCache(c.seed, f);
        _highland = _highland.copyWith(
          climb: () => c.copyWith(
            floor: f,
            wind: c.wind + SkyWalkRules.floor(f).wind,
            opened: [b.entrance],
            hero: b.entrance,
          ),
        );
        await _saveHighland();
        _notify();
        return true;
      });

  /// 구름 걷기를 끝낸다 (내려가기 · 바람 · HP · 섬이 떠남). 얻은 것은 그대로. 결과 창 숫자
  Future<SkyClimbSummary> endSkyClimb() => _serial(() async {
        final c = _highland.climb;
        if (c == null) return const SkyClimbSummary(floor: 0);
        _highland = _highland.copyWith(climb: () => null);
        await _saveHighland();
        await _tripFought('sky');
        _notify();
        return SkyClimbSummary.of(c);
      });

  // ───────────── 석상 병사 (밝히면 바로 짧게 싸움 · 지금 HP)

  Battle? startSoldierBattle() {
    final s = skyIsland;
    final c = skyClimb;
    if (s == null || c?.soldier == null || hp <= 0) return null;
    return _ashBattle(
        [HighlandRules.soldierFoe(s.isle, player.level.level)]);
  }

  /// 석상 병사와 싸운 뒤: 이기면 하늘 돌 조각 조금 · 판으로. 지면 이번 오르기 끝 (얻은 것은 그대로)
  Future<SkyResult> finishSoldierBattle(Battle battle) => _serial(() async {
        final c = skyClimb;
        if (!battle.isOver) return const SkyResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        if (battle.phase != BattlePhase.cleared) {
          // 지면 이번 오르기는 끝 (얻은 것은 그대로)
          final sum = c == null ? null : SkyClimbSummary.of(c);
          _highland = _highland.copyWith(climb: () => null);
          await _saveHighland();
          await _tripFought('sky');
          await _defeated();
          _notify();
          return SkyResult(won: false, climb: sum);
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
        if (c != null) {
          _highland = _highland.copyWith(
              climb: () => c.copyWith(soldier: () => null, stones: c.stones + n));
          await _saveHighland();
        }
        await _grant(0, 0, mats);
        _notify();
        return SkyResult(won: true, isle: skyIsland?.isle, mats: mats);
      });

  // ───────────── 수호자 (턴제)

  /// 제단에서 수호자를 깨운다. 깨운 뒤 나가면 진 것으로 본다
  Future<SkyTurn?> startGuardianTurn() => _serial(() async {
        final s = skyIsland;
        final c = skyClimb;
        if (s == null || c == null || !canWakeGuardian) return null;
        final lv = player.level.level;
        final b = _ashBattle([HighlandRules.guardianFoe(s.isle, lv)]);
        final pet = companionPet;
        final first = !_highland.fought.contains(s.isle.index);
        _highland = _highland.copyWith(
          climb: () => c.copyWith(awake: true),
          fought: first ? [..._highland.fought, s.isle.index] : null,
        );
        await _saveHighland();
        return SkyTurn(
          isle: s.isle,
          level: lv,
          heroMaxHp: b.playerMaxHp,
          heroHp: b.playerHp,
          heroAttack: b.playerAttack,
          crit: b.playerCrit,
          evade: b.playerEvade,
          damageTaken: b.damageTaken,
          skyTaken: gear.sets.skyTaken,
          mp: _jobs.awakened ? jobMp : 0,
          mpMax: _jobs.awakened ? jobMpMax : 0,
          skills: [
            if (_jobs.awakened)
              for (final (sk, cost, power) in battleJobSlots.take(2))
                AshTurnSkill(
                    key: sk.name,
                    name: JobRules.skill(sk).name,
                    mp: cost,
                    attack: JobRules.skill(sk).attack,
                    power: power),
          ],
          hasPet: pet != null,
          petAdult: pet?.adult ?? false,
          potions: [for (final p in battlePotions) if (p.hpRatio > 0) p],
          hints: first,
          rng: _random,
        );
      });

  /// 깨운 수호자를 두고 나갔을 때 (앱을 다시 켬 · 뒤로): 진 것으로
  bool get skyGuardianAbandoned => skyClimb?.awake ?? false;

  /// 수호자 턴제가 끝났을 때 (이겨도 · 져도 · 나가도). 이번 오르기도 끝난다
  Future<SkyResult> finishGuardianTurn(SkyTurn? t) => _serial(() async {
        final c = _highland.climb;
        final s = skyIsland;
        final isle = t?.isle ?? s?.isle;
        if (isle == null) return const SkyResult(won: false);
        final i = HighlandRules.info(isle);
        await _tripFought('sky');
        final summary = c == null ? null : SkyClimbSummary.of(c);
        _highland = _highland.copyWith(climb: () => null);
        await _saveHighland();
        if (t != null) {
          await _consumePotionKeys(t.potionsUsed);
          _vitals = _vitals.copyWith(hp: t.hp, lastMaxHp: maxHp);
          await store.saveVitals(_vitals);
          if (_jobs.awakened) await _setJobMp(t.mp);
        }
        await _spendBattleBuffs();
        if (t == null || !t.won) {
          await _defeated();
          _notify();
          return SkyResult(won: false, isle: isle, climb: summary);
        }
        final first = !_highland.beaten.contains(isle.index);
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
        final beaten = first ? [..._highland.beaten, isle.index] : _highland.beaten;
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
            for (final x in titles) TitleRules.skyCounter(x): 1,
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
          isle: isle,
          mats: mats,
          exp: exp,
          titles: titles,
          climb: summary,
        );
      });

  // ───────────── 비문 (기록 탭)

  /// 비문 다섯 자리 (얻은 자리만 글, 나머지는 null)
  List<String?> get skyInscriptions => [
        for (final i in HighlandRules.isles)
          _highland.beaten.contains(i.id.index) ? i.inscription : null,
      ];

  Future<void> _saveHighland() =>
      _saveJson(AppController._highlandKey, _highland.toJson());
}
