part of '../app_controller.dart';

/// 3막 필드 싸움 결과
class Act3FightResult {
  const Act3FightResult({
    required this.won,
    this.exp = 0,
    this.gold = 0,
    this.items = const [],
    this.allyLevels = const {},
    this.firstFight = false,
  });

  final bool won;
  final int exp;
  final int gold;

  /// 떨어진 장비
  final List<EquipItem> items;

  /// 레벨이 오른 동료 (이름 → 새 레벨)
  final Map<String, int> allyLevels;

  /// 메인 ① 「잿빛 들판에서 첫 싸움」을 이번에 끝냈는지
  final bool firstFight;
}

/// 3막 다리 너머 탐험 (묶음 52 #243): 틀.
/// 열리는 때 · 다리 장면 · 걸음(다음 지역 길 · 여정 기력 · 모집권) · 동료(주점) · 지역 1 필드 사냥 · 전리품
extension Act3Ops on AppController {
  Act3State get act3 => _act3;

  String get _a3Day => DailyRecord.dayKeyOf(_clock());

  // ───────────── 열리는 때 (Lv.21 + 본체 뒤 + 결말 뒤 만남을 지남)

  bool get act3Available =>
      _act2Ready &&
      !inTutorial &&
      _act2.kingDone &&
      _village.contains('meet') &&
      player.level.level >= Act3Rules.openLevel;

  /// 처음 다리를 건너는 장면을 볼 때 (#124: 예전 Lv.21 이상 결말 계정도 다음에 다리를 누르면)
  bool get bridgeScenePending => act3Available && !_act3.sceneSeen;

  /// 다리 장면을 끝냈을 때: 3막이 열린다 (리안 · 가렌이 주점 동료 · 처음 모집권 · 이때부터 걸음을 셈)
  Future<void> openAct3() => _serial(() async {
        if (!act3Available || _act3.opened) {
          if (!_act3.sceneSeen) {
            _act3 = _act3.copyWith(sceneSeen: true);
            await _saveAct3();
          }
          return;
        }
        final lv = player.level.level;
        final steps = player.today?.steps ?? 0;
        AllyData story(StoryAlly a) => AllyData(
              id: a.name,
              story: a.name,
              name: Act3Rules.story(a).name,
              stats: Act3Rules.story(a).stats,
              level: math.max(1, lv - 1),
              joinLevel: math.max(1, lv - 1),
            );
        _act3 = _act3.copyWith(
          opened: true,
          sceneSeen: true,
          walkDay: _a3Day,
          walkSteps: steps,
          ticketDay: _a3Day,
          ticketSteps: steps,
          energy: Act3Rules.energyMax,
          tickets: _act3.tickets + Act3Rules.ticketStarter,
          allies: [story(StoryAlly.lian), story(StoryAlly.garen)],
          party: const ['lian', 'garen'],
        );
        await _saveAct3();
        _notify();
      });

  bool get act3Open => act3Available && _act3.opened;

  // ───────────── 걸음 (3막이 열린 뒤만): 다음 지역 길 · 여정 기력 · 모집권

  Future<void> _act3Walk() async {
    if (!_act3.opened) return;
    final today = player.today;
    if (today == null) return;
    final day = today.dayKey;
    final from = _act3.walkDay == day ? _act3.walkSteps : 0;
    final delta = today.steps - from;
    var s = _act3;
    if (delta > 0) {
      final rem = s.energyRem + delta;
      final add = rem ~/ Act3Rules.energyStepUnit * Act3Rules.energyPerStep;
      s = s.copyWith(
        walkDay: day,
        walkSteps: today.steps,
        roadSteps: s.roadSteps + delta,
        energy: math.min(Act3Rules.energyMax, s.energy + add),
        energyRem: rem % Act3Rules.energyStepUnit,
      );
    } else if (s.walkDay != day) {
      s = s.copyWith(walkDay: day, walkSteps: today.steps);
    }
    // 모집권: 5,000보마다 1장 (하루 2장까지)
    final tDay = s.ticketDay == day;
    final base = tDay ? s.ticketSteps : 0;
    final got = tDay ? s.ticketGot : 0;
    final want = math.min(Act3Rules.ticketStepsPerDay,
        math.max(0, today.steps - base) ~/ Act3Rules.ticketSteps);
    if (!tDay) s = s.copyWith(ticketDay: day, ticketSteps: 0, ticketGot: 0);
    if (want > got) {
      s = s.copyWith(tickets: s.tickets + want - got, ticketGot: want);
    }
    if (!identical(s, _act3)) {
      _act3 = s;
      await _saveAct3();
      _notify();
    }
  }

  int get journeyEnergy => _act3.energy;
  int get recruitTickets => _act3.tickets;

  /// 다음 지역 길 (걸은 걸음 · 필요한 걸음 · 다음 지역 · 레벨이 되는지)
  ({int steps, int need, RegionInfo? next, bool levelOk}) get road {
    final i = _act3.region + 1;
    final next = i < Act3Rules.regions.length ? Act3Rules.regions[i] : null;
    return (
      steps: _act3.roadSteps,
      need: Act3Rules.roadSteps,
      next: next,
      levelOk: next != null && player.level.level >= next.level,
    );
  }

  RegionInfo get currentRegion => Act3Rules.regions[_act3.region.clamp(0, 4)];

  /// 광고로 모집권 (하루 1장)
  bool get canAdTicket => adsReady && act3Open && _act3.adDay != _a3Day;

  Future<bool> adTicket() async {
    if (!canAdTicket || !await _watchAd('recruit_ticket')) return false;
    return _serial(() async {
      _act3 = _act3.copyWith(adDay: _a3Day, tickets: _act3.tickets + 1);
      await _saveAct3();
      _notify();
      return true;
    });
  }

  // ───────────── 동료 (주점 「동료」 탭)

  List<AllyData> get allies => _act3.allies;
  List<AllyData> get nameless => [for (final a in _act3.allies) if (!a.isStory) a];

  /// 데려가는 동료 (2명까지)
  List<AllyData> get partyAllies => [
        for (final id in _act3.party)
          if (_act3.ally(id) case final a?) a,
      ];

  /// 이름 없는 동료 보유 한도: 처음 4 · 리안과 친해질 때마다 +1 (최대 +3)
  int get rosterLimit =>
      Act3Rules.rosterBase + math.min(3, favorStage(Npc.lian).index);

  bool get rosterFull => nameless.length >= rosterLimit;

  /// 모험가 한 명을 뽑는다 (모집권 1장). 못 뽑으면 null
  Future<AllyData?> recruit() => _serial(() async {
        if (!act3Open || _act3.tickets < 1 || rosterFull) return null;
        final r = _random;
        final race = AllyRace.values[r.nextInt(AllyRace.values.length)];
        final job = AllyJob.values[r.nextInt(AllyJob.values.length)];
        final high = r.nextDouble() < Act3Rules.highChance;
        int stat(int i) {
          final lo = high ? 1.0 : Act3Rules.rollMin;
          final hi = high ? Act3Rules.rollHigh : 1.0;
          var v = Act3Rules.baseStat * (lo + r.nextDouble() * (hi - lo));
          if (Act3Rules.raceStat[race] == i) v *= 1.1;
          return math.max(1, v.round());
        }

        final pool = [...Act3Rules.traits]..shuffle(r);
        final traits = [
          for (final t in pool.take(r.nextDouble() < Act3Rules.twoTraits ? 2 : 1)) t.id,
        ];
        final lv = math.max(1, player.level.level - 2);
        final a = AllyData(
          id: 'a${_act3.nextId}',
          race: race.name,
          job: job.name,
          name: Act3Rules.names[r.nextInt(Act3Rules.names.length)],
          stats: [for (var i = 0; i < 4; i++) stat(i)],
          traits: traits,
          level: lv,
          joinLevel: lv,
        );
        _act3 = _act3.copyWith(
          tickets: _act3.tickets - 1,
          allies: [..._act3.allies, a],
          nextId: _act3.nextId + 1,
        );
        await _saveAct3();
        await _npcUse(Npc.lian);
        _notify();
        return a;
      });

  /// 이름 없는 동료 이름 바꾸기 (마을 사람 이름은 안 됨)
  Future<bool> renameAlly(String id, String name) => _serial(() async {
        final a = _act3.ally(id);
        final n = name.trim();
        if (a == null || a.isStory || n.isEmpty || npcNameReserved(n)) return false;
        _act3 = _act3.replaceAlly(a.copyWith(name: n));
        await _saveAct3();
        _notify();
        return true;
      });

  /// 내보내기: 금화 조금 + 입던 장비는 가방으로 (이야기 동료는 내보낼 수 없음)
  Future<bool> releaseAlly(String id) => _serial(() async {
        final a = _act3.ally(id);
        if (a == null || a.isStory) return false;
        for (final g in a.gear) {
          await _giveEquipOrMail(g, title: '동료가 맡겨 둔 장비');
        }
        _act3 = _act3.copyWith(
          allies: [for (final x in _act3.allies) if (x.id != id) x],
          party: [for (final p in _act3.party) if (p != id) p],
        );
        await _saveAct3();
        await _grant(Act3Rules.releaseGold, 0, const {});
        _notify();
        return true;
      });

  /// 데려갈 동료를 고른다 (2명까지, 같은 사람 두 번은 안 됨)
  Future<void> setParty(List<String> ids) => _serial(() async {
        final ok = [
          for (final id in ids.toSet())
            if (_act3.ally(id) != null) id,
        ].take(2).toList();
        _act3 = _act3.copyWith(party: ok);
        await _saveAct3();
        _notify();
      });

  // 장비: 내 가방 장비를 입힘 (동료가 입은 건 나는 못 입음 — 가방에서 동료에게 옮김)

  /// 동료에게 입힐 수 있는 가방 장비 (내가 입은 것은 빼고)
  List<EquipItem> allyGearChoices(EquipSlot slot) => [
        for (final i in _armory.items)
          if (i.slot == slot && !_armory.isWorn(i)) i,
      ];

  Future<bool> equipAlly(String allyId, String uid) => _serial(() async {
        final a = _act3.ally(allyId);
        final item = _armory.byUid(uid);
        if (a == null || item == null || _armory.isWorn(item)) return false;
        final old = [for (final g in a.gear) if (g.slot == item.slot) g];
        await _saveArmory(_armory.copyWith(items: [
          for (final i in _armory.items) if (i.uid != uid) i,
          ...old,
        ]));
        _act3 = _act3.replaceAlly(a.copyWith(gear: [
          for (final g in a.gear) if (g.slot != item.slot) g,
          item,
        ]));
        await _saveAct3();
        _notify();
        return true;
      });

  Future<bool> unequipAlly(String allyId, EquipSlot slot) => _serial(() async {
        final a = _act3.ally(allyId);
        if (a == null) return false;
        final old = [for (final g in a.gear) if (g.slot == slot) g];
        if (old.isEmpty) return false;
        for (final g in old) {
          await _giveEquipOrMail(g, title: '동료가 맡겨 둔 장비');
        }
        _act3 = _act3.replaceAlly(
            a.copyWith(gear: [for (final g in a.gear) if (g.slot != slot) g]));
        await _saveAct3();
        _notify();
        return true;
      });

  // 스킬 4칸 (① → ②·③ → ④, 동료 레벨이 오르면 포인트)

  List<AllySkillInfo> allySkills(AllyData a) => a.isStory
      ? Act3Rules.story(StoryAlly.values.byName(a.story!)).skills
      : Act3Rules.jobSkills(AllyJob.values.byName(a.job!));

  int allyPoints(AllyData a) {
    final total = math.max(0, a.level - a.joinLevel) ~/ Act3Rules.levelsPerPoint;
    final spent = a.skills.fold<int>(0, (t, s) => t + Act3Rules.skillCost(s));
    return total - spent;
  }

  /// 이 칸을 열 수 있는지 (앞 칸 · 포인트 · 퀘스트)
  bool canUnlockSkill(AllyData a, int slot) {
    if (a.skills.contains(slot) || slot < 0 || slot > 3) return false;
    if (a.isStory && Act3Rules.lockedByQuest(StoryAlly.values.byName(a.story!), slot)) {
      return false;
    }
    final pre = switch (slot) {
      1 || 2 => a.skills.contains(0),
      3 => a.skills.contains(1) && a.skills.contains(2),
      _ => true,
    };
    return pre && allyPoints(a) >= Act3Rules.skillCost(slot);
  }

  Future<bool> unlockAllySkill(String id, int slot) => _serial(() async {
        final a = _act3.ally(id);
        if (a == null || !canUnlockSkill(a, slot)) return false;
        _act3 = _act3.replaceAlly(a.copyWith(skills: [...a.skills, slot]..sort()));
        await _saveAct3();
        _notify();
        return true;
      });

  /// 전투 버튼에 끼울 스킬
  Future<bool> setAllySkill(String id, int slot) => _serial(() async {
        final a = _act3.ally(id);
        if (a == null || !a.skills.contains(slot)) return false;
        _act3 = _act3.replaceAlly(a.copyWith(slot: slot));
        await _saveAct3();
        _notify();
        return true;
      });

  // 동료 보여 주기

  String allyJobName(AllyData a) => a.isStory
      ? Act3Rules.story(StoryAlly.values.byName(a.story!)).roleName
      : '${Act3Rules.raceNames[AllyRace.values.byName(a.race!)]} '
          '${Act3Rules.jobNames[AllyJob.values.byName(a.job!)]}';

  ({String? art, String? face, int color}) allyLook(AllyData a) {
    if (a.isStory) {
      final s = Act3Rules.story(StoryAlly.values.byName(a.story!));
      return (art: s.image, face: s.face, color: 0xFFE8C77A);
    }
    return (
      art: null,
      face: null,
      color: Act3Rules.jobColor[AllyJob.values.byName(a.job!)] ?? 0xFF9AA6D8,
    );
  }

  /// 마법사 속성 (종족에 따라)
  Element? allyElement(AllyData a) {
    if (a.isStory || a.job != AllyJob.mage.name) return null;
    return Act3Rules.mageElement[AllyRace.values.byName(a.race!)];
  }

  /// 전투에 나오는 동료 (지금 레벨 · 능력치 · 장비 · 특성)
  BattleAlly battleAlly(AllyData a) {
    final lv = a.level;
    final g = EquipmentRules.bonusOf(a.gear);
    final traits = [for (final t in a.traits) if (Act3Rules.trait(t) case final x?) x];
    double sum(double Function(AllyTraitInfo) f) => traits.fold(0.0, (t, x) => t + f(x));
    final job = a.isStory ? null : AllyJob.values.byName(a.job!);
    final magic = job == AllyJob.mage || job == AllyJob.priest;
    final atkStat = (magic ? a.stats[3] : a.stats[0]) / Act3Rules.baseStat;
    final hpStat = a.stats[1] / Act3Rules.baseStat;
    final skills = allySkills(a);
    final skill = a.skills.contains(a.slot) ? skills[a.slot] : skills[a.skills.first];
    Element? bonus;
    for (final t in traits) {
      bonus ??= t.element;
    }
    return BattleAlly(
      id: a.id,
      name: a.name,
      maxHp: math.max(1, (BattleRules.expectedMaxHp(lv) * Act3Rules.allyHp * hpStat *
              (1 + g.maxHp + sum((t) => t.hp)))
          .round()),
      attack: math.max(1, (BattleRules.expectedAttack(lv) * Act3Rules.allyAttack * atkStat *
              (1 + g.attack + sum((t) => t.attack)))
          .round()),
      skill: skill,
      chargeTicks: math.max(3, Act3Rules.allyCharge - sum((t) => t.charge.toDouble()).round()),
      crit: (0.05 + (a.stats[2] - Act3Rules.baseStat) * 0.01 + sum((t) => t.crit))
          .clamp(0.0, 0.5),
      element: allyElement(a),
      heal: sum((t) => t.heal),
      ash: sum((t) => t.ash),
      elementBonus: bonus,
    );
  }

  // ───────────── 지역 1 필드 사냥 (여정 기력 5)

  bool canFieldFight(String placeId) =>
      act3Open &&
      _act3.energy >= Act3Rules.energyField &&
      hp > 0 &&
      Act3Rules.place(placeId)?.monster != null;

  Battle? startAct3Fight(String placeId) {
    final p = Act3Rules.place(placeId);
    final m = p?.monster;
    if (m == null || !canFieldFight(placeId)) return null;
    final lv = player.level.level;
    // 잿빛 들판 고블린은 무리로 (둘)
    final floors = [
      Act3Rules.fieldFoe(m, lv),
      if (m == MonsterId.goblinRaider) Act3Rules.fieldFoe(m, lv),
    ];
    _act3 = _act3.copyWith(energy: _act3.energy - Act3Rules.energyField);
    unawaited(_saveAct3());
    final p0 = player;
    _stopResting();
    return _withJob(Battle.forPlayer(
      level: p0.level.level,
      stats: combatStats,
      floors: floors,
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p0),
      gear: gear,
      power: combatPower() * jobPower,
      petSkill: companionPet?.info.skill,
      petAdult: companionPet?.adult ?? false,
      petResonant: companionPet != null && petResonant(companionPet!),
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: companionPet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
      telegraphs: true,
      heroSkills: true,
      allies: [for (final a in partyAllies) battleAlly(a)],
    ));
  }

  /// 필드 싸움이 끝났을 때: 이기면 경험치 · 금화 · 가끔 「발드린 문지기」 장비 · 동료 경험치.
  /// 지면 얻은 것은 그대로, 그 지역 마을로 돌아감(화면) · 여정 기력만 쓴 만큼
  Future<Act3FightResult> finishAct3Fight(Battle battle) => _serial(() async {
        if (!battle.isOver) return const Act3FightResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        if (battle.phase != BattlePhase.cleared) {
          await _defeated();
          _notify();
          return const Act3FightResult(won: false);
        }
        final exp = Act3Rules.fieldExp * battle.floors.length;
        final gold = Act3Rules.fieldGoldMin +
            _random.nextInt(Act3Rules.fieldGoldMax - Act3Rules.fieldGoldMin + 1);
        final today = await _todayRecord();
        await _save(today.copyWith(
          gains: DailyRecord.addCounts(today.gains, {'exp': exp, Wallet.gold: gold}),
          counters: DailyRecord.addCounts(today.counters, {'act3Fight': 1}),
        ));
        // 장비: 가끔 하나 (훔치기면 한 번 더 굴림)
        final items = <EquipItem>[];
        for (var k = 0; k < (battle.extraLoot ? 2 : 1); k++) {
          if (_random.nextDouble() >= Act3Rules.gearDrop) continue;
          final base = Act3Rules.baldrinGear[_random.nextInt(Act3Rules.baldrinGear.length)];
          final grade = EquipmentRules.rollGrade(_random);
          final a = _armory;
          final item = EquipItem(
            uid: 'eq${a.nextId}',
            base: base,
            grade: grade,
            extras: EquipmentRules.rollExtras(grade, _random),
            element: base == EquipBase.baldrinWeapon ? Element.light : null,
          );
          await _saveArmory(a.copyWith(nextId: a.nextId + 1));
          await _giveEquipOrMail(item, title: '저쪽 세계 전리품');
          items.add(item);
        }
        // 동료 경험치 (내 레벨을 넘지 못함)
        final ups = <String, int>{};
        var s = _act3;
        for (final id in s.party) {
          final a = s.ally(id);
          if (a == null) continue;
          var lv = a.level, xp = a.exp + Act3Rules.allyExpField;
          while (lv < player.level.level && xp >= Act3Rules.allyExpToNext(lv)) {
            xp -= Act3Rules.allyExpToNext(lv);
            lv++;
          }
          if (lv >= player.level.level) xp = 0;
          if (lv != a.level) ups[a.name] = lv;
          s = s.replaceAlly(a.copyWith(level: lv, exp: xp));
          // 마을 사람 동료는 함께 싸우면 친해지기 점수 (하루 쓰기 한도 안)
          if (a.story == StoryAlly.lian.name) await _npcUse(Npc.lian);
          if (a.story == StoryAlly.garen.name) await _npcUse(Npc.garen);
        }
        final first = !s.firstFight &&
            battle.floors.first.monster == MonsterId.goblinRaider;
        _act3 = s.copyWith(firstFight: s.firstFight || first, wins: s.wins + 1);
        await _saveAct3();
        await gainMastery(Mastery.combat, MasteryRules.fieldWin);
        _notify();
        return Act3FightResult(
          won: true,
          exp: exp,
          gold: gold,
          items: items,
          allyLevels: ups,
          firstFight: first,
        );
      });

  /// 동료 다음 레벨까지 경험치
  int allyExpToNext(AllyData a) => Act3Rules.allyExpToNext(a.level);

  /// 일지 (메인): 이번 묶음은 ①만, 나머지는 「다음 이야기」
  List<({String title, String text, bool done})> get journalMain => [
        (
          title: Act3Rules.mainFirstFight,
          text: Act3Rules.mainFirstFightText,
          done: _act3.firstFight,
        ),
      ];

  Future<void> _saveAct3() =>
      store.saveJson(AppController._act3Key, _act3.toJson());
}
