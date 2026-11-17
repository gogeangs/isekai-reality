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
    this.lines = const [],
    this.tickets = 0,
    this.lamp = false,
  });

  /// 묶음 53: 이야기 한 줄 (은빛 털 · 편지 · 퀘스트 진행 등)
  final List<String> lines;

  /// 받은 모집권
  final int tickets;

  /// 이번에 처음 등불을 켰는지 (등불 장면을 보여 줌)
  final bool lamp;

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
    final before = _act3;
    var s = _act3;
    if (delta > 0) {
      final rem = s.energyRem + delta;
      var add = rem ~/ Act3Rules.energyStepUnit * Act3Rules.energyPerStep;
      // 묶음 57 #244 아스트라(페가수스)와 걸으면 여정 기력이 조금 더 (숨김)
      if (add > 0 && _heroWith(PetSpecies.pegasus)) add += (add * PetRules.pegasusEnergy).ceil();
      _act3 = s;
      _regionWalk(delta);
      s = _act3;
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
    if (!identical(s, before)) {
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
  /// 묶음 54: 주점 ★2 · ★3 마다 +2
  int get rosterLimit =>
      Act3Rules.rosterBase +
      math.min<int>(3, favorStage(Npc.lian).index) +
      (buildingsOpen ? (buildingStar(Building.tavern) - 1) * BuildingRules.rosterPerStar : 0);

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
        if (a == null || a.isStory || n.isEmpty || npcNameReserved(n) || NameRules.banned(n)) return false;
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
    if (a.isStory &&
        Act3Rules.lockedByQuest(StoryAlly.values.byName(a.story!), slot) &&
        !allyQuestDone(StoryAlly.values.byName(a.story!))) {
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
    // 묶음 53: 직업 그림 6장 (종족 특징은 아직 없음)
    final img = 'assets/images/ally_job_${a.job}.webp';
    return (
      art: img,
      face: img,
      color: Act3Rules.jobColor[AllyJob.values.byName(a.job!)] ?? 0xFF9AA6D8,
    );
  }

  /// 동료가 든 무기가 직업에 잘 맞는지 (숨은 값 공격 +10%)
  bool allyWeaponFits(AllyData a) {
    final w = [for (final g in a.gear) if (g.slot == EquipSlot.weapon) g].firstOrNull;
    final kind = MasteryRules.weaponKind(w?.base);
    if (kind == null) return false;
    final role = a.isStory
        ? Act3Rules.story(StoryAlly.values.byName(a.story!)).role
        : AllyJob.values.byName(a.job!);
    final fit = a.story == StoryAlly.garen.name
        ? const {'staff', 'spear'}
        : Act3Rules.jobWeapons[role] ?? const <String>{};
    return fit.contains(kind);
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
              (1 + g.attack + sum((t) => t.attack) + (allyWeaponFits(a) ? Act3Rules.fitBonus : 0)))
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

  // ───────────── 싸움 (필드 · 요새 층 · 보스 · 이야기 싸움): 묶음 53에서 [A3Enc] 로 묶음

  bool canFieldFight(String placeId) =>
      act3Open &&
      _act3.energy >= Act3Rules.energyField &&
      hp > 0 &&
      Act3Rules.place(placeId)?.monster != null;

  /// 지역 지도의 필드 사냥 (여정 기력 5). 잿빛 들판 고블린은 무리로 (둘)
  Battle? startAct3Fight(String placeId) {
    final m = Act3Rules.place(placeId)?.monster;
    if (m == null || !canFieldFight(placeId)) return null;
    return startEncounter(A3Enc(
      kind: A3Kind.field,
      place: placeId,
      foes: [m, if (m == MonsterId.goblinRaider) m],
      energy: Act3Rules.energyField,
    ));
  }

  /// 싸움 하나를 시작한다 (여정 기력을 쓰는 싸움이면 먼저 씀). 못 하면 null
  Battle? startEncounter(A3Enc e) {
    if (!act3Open || hp <= 0 || _act3.energy < e.energy) return null;
    final lv = player.level.level;
    final reg = RegionRules.byPlace(e.place ?? '');
    final floors = [for (final m in e.foes) _a3Foe(m, e.kind, lv, reg)];
    if (e.energy > 0) {
      _act3 = _act3.copyWith(energy: _act3.energy - e.energy);
      unawaited(_saveAct3());
    }
    _a3Enc = e;
    final p0 = player;
    _stopResting();
    return _withUnicorn(_withJob(Battle.forPlayer(
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
    )));
  }

  /// 묶음 57 #244: 루체(유니콘)와 함께면 3막에서 져도 한 번 그 자리에서 다시 일어남
  Battle _withUnicorn(Battle b) {
    if (_heroWith(PetSpecies.unicorn)) b.revives += 1;
    // 묶음 57 지역 2~5 이름 있는 장비 (숨김)
    bool worn(EquipBase x) => _armory.items.any((i) => i.base == x && _armory.isWorn(i));
    if (worn(EquipBase.uniqPhoenixCharm)) b.revives += RegionRules.phoenixCharmRevive;
    final h = _clock().hour;
    if (worn(EquipBase.uniqMoonFang) && (h >= 19 || h < 6)) b.dealMult *= 1 + RegionRules.moonFangNight;
    final w = _armory.wornIn(EquipSlot.weapon);
    if (w?.base == EquipBase.uniqGrumHammer) {
      b.dealMult *= 1 + RegionRules.grumHammerPerLevel * w!.enhance;
    }
    return b;
  }

  Foe _a3Foe(MonsterId m, A3Kind k, int lv, [RegionContent? reg]) {
    final (hpX, atkX) = switch (k) {
      A3Kind.mid => (BaldrinRules.midHp, BaldrinRules.midAtk),
      A3Kind.lamp => (BaldrinRules.lampHp, BaldrinRules.lampAtk),
      A3Kind.den => (BaldrinRules.denHp, BaldrinRules.denAtk),
      _ => (Act3Rules.fieldHp, Act3Rules.fieldAttack),
    };
    // 묶음 57: 지역 2~5는 그 지역 레벨 · 지역마다 조금 더 · 심층은 층마다 더
    final regionLv = reg == null ? Act3Rules.openLevel : Act3Rules.region(reg.region).level;
    final b = BattleRules.fieldFoe(level: math.max(lv, regionLv), monster: m);
    var scale = reg == null ? 1.0 : RegionRules.hpScale(reg.region);
    if (reg != null && regionFloorNow(reg) > reg.floors.length &&
        (k == A3Kind.floor || k == A3Kind.mid)) {
      scale *= RegionRules.deepScale(regionFloorNow(reg));
    }
    return Foe(
      monster: m,
      maxHp: math.max(1, (b.maxHp * hpX * scale).round()),
      attack: math.max(1, (b.attack * atkX * (1 + (scale - 1) / 2)).round()),
      defense: b.defense,
      speed: b.speed,
    );
  }

  /// 장비 하나를 굴려 가방(넘치면 우편)으로
  Future<EquipItem> _a3Gear(EquipBase base, {bool rare = false, Element? element}) async {
    final grade = EquipmentRules.rollGrade(_random, rare: rare);
    final a = _armory;
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      element: element ?? (base == EquipBase.baldrinWeapon ? Element.light : null),
    );
    await _saveArmory(a.copyWith(nextId: a.nextId + 1));
    await _giveEquipOrMail(item, title: '저쪽 세계 전리품');
    if (BaldrinRules.uniques.contains(base) ||
        RegionRules.all.any((r) => r.uniques.contains(base))) {
      _act3 = _act3.copyWith(found: {..._act3.found, base.name});
    }
    return item;
  }

  Future<EquipItem> _a3Normal([RegionContent? r]) {
    final pool = r?.gear ?? Act3Rules.baldrinGear;
    return _a3Gear(pool[_random.nextInt(pool.length)], element: r?.weaponElement);
  }

  /// 이름 있는 장비 하나 (아직 없는 것 먼저)
  Future<EquipItem> _a3Unique(List<EquipBase> from) {
    final fresh = [for (final b in from) if (!_act3.found.contains(b.name)) b];
    final pool = fresh.isEmpty ? from : fresh;
    final base = pool[_random.nextInt(pool.length)];
    return _a3Gear(base,
        rare: true, element: base == EquipBase.uniqTeoSpear ? Element.light : null);
  }

  /// 싸움이 끝났을 때: 이기면 경험치 · 금화 · 장비 · 동료 경험치 · 퀘스트 진행.
  /// 지면 얻은 것은 그대로, 그 지역 마을로 돌아감(화면) · 여정 기력만 쓴 만큼
  Future<Act3FightResult> finishAct3Fight(Battle battle) => _serial(() async {
        final e = _a3Enc ?? const A3Enc(kind: A3Kind.field, foes: []);
        _a3Enc = null;
        if (!battle.isOver) return const Act3FightResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        if (battle.phase != BattlePhase.cleared) {
          await _defeated();
          _notify();
          return const Act3FightResult(won: false);
        }
        final reg = RegionRules.byPlace(e.place ?? '');
        final boss = e.kind == A3Kind.mid || e.kind == A3Kind.lamp || e.kind == A3Kind.den;
        final exp = switch (e.kind) {
          A3Kind.mid => RuleConstants.fieldMonsterExp * BaldrinRules.midExp,
          A3Kind.lamp => RuleConstants.fieldMonsterExp * BaldrinRules.lampExp,
          A3Kind.den => RuleConstants.fieldMonsterExp * BaldrinRules.denExp,
          _ => Act3Rules.fieldExp * battle.floors.length,
        };
        var gold = boss
            ? BaldrinRules.bossGoldMin +
                _random.nextInt(BaldrinRules.bossGoldMax - BaldrinRules.bossGoldMin + 1)
            : Act3Rules.fieldGoldMin +
                _random.nextInt(Act3Rules.fieldGoldMax - Act3Rules.fieldGoldMin + 1);
        // 묶음 57: 흑등 상회의 빛 등불 — 이기면 금화 조금 더 (숨김)
        if (_armory.items.any((i) => i.base == EquipBase.uniqBlackLantern && _armory.isWorn(i))) {
          gold = (gold * (1 + RegionRules.blackLanternGold)).round();
        }
        final today = await _todayRecord();
        await _save(today.copyWith(
          gains: DailyRecord.addCounts(today.gains, {'exp': exp, Wallet.gold: gold}),
          counters: DailyRecord.addCounts(today.counters, {'act3Fight': 1}),
        ));
        final items = <EquipItem>[];
        final lines = <String>[];
        var tickets = 0;
        // 장비: 보통 싸움은 가끔 하나 (훔치기면 한 번 더), 보스는 더 자주
        final gearChance = switch (e.kind) {
          A3Kind.mid => 0.6,
          A3Kind.lamp || A3Kind.den => 1.0,
          _ => Act3Rules.gearDrop,
        };
        for (var k = 0; k < (battle.extraLoot ? 2 : 1); k++) {
          if (_random.nextDouble() < gearChance) items.add(await _a3Normal(reg));
        }
        // 이름 있는 장비 (아주 드물게, 숨은 보스는 처음 한 번 꼭)
        final firstDen = e.kind == A3Kind.den &&
            !_act3.has(reg == null ? 'denBoss' : '${reg.prefix}:hiddenBoss');
        final uChance = reg != null
            ? switch (e.kind) {
                A3Kind.lamp => RegionRules.uniqLamp,
                A3Kind.mid => RegionRules.uniqMid,
                A3Kind.den => firstDen ? 1.0 : RegionRules.uniqHidden,
                _ => 0.0,
              }
            : switch (e.kind) {
          A3Kind.lamp => BaldrinRules.uniqLamp,
          A3Kind.mid => BaldrinRules.uniqMid,
          A3Kind.den => firstDen ? 1.0 : BaldrinRules.uniqDen,
          _ => 0.0,
        };
        if (reg != null && _random.nextDouble() < uChance) {
          items.add(await _a3Unique(reg.uniques));
        } else if (reg == null && _random.nextDouble() < uChance) {
          items.add(await _a3Unique(switch (e.kind) {
            A3Kind.den => const [EquipBase.uniqWindPendant],
            A3Kind.lamp => const [EquipBase.uniqVolkHelm, EquipBase.uniqTeoSpear],
            _ => const [EquipBase.uniqVolkHelm],
          }));
        }
        // 동료 경험치 (내 레벨을 넘지 못함)
        final ups = <String, int>{};
        var s = _act3;
        for (final id in s.party) {
          final a = s.ally(id);
          if (a == null) continue;
          var lv = a.level, xp = a.exp + Act3Rules.allyExpField * (boss ? 3 : 1);
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
          // 묶음 57: 바르칸 · 포포 · 세라도 마을 사람 친해지기와 이어짐
          if (a.story == StoryAlly.barkan.name) await _npcUse(Npc.barkan);
          if (a.story == StoryAlly.popo.name) await _npcUse(Npc.popo);
          if (a.story == StoryAlly.sera.name) await _npcUse(Npc.sera);
        }
        final first = !s.firstFight &&
            battle.floors.first.monster == MonsterId.goblinRaider &&
            e.kind == A3Kind.field;
        _act3 = s.copyWith(firstFight: s.firstFight || first, wins: s.wins + 1);
        // 묶음 57: 지역 2~5
        var lampNow = false;
        if (reg != null) {
          final (t, l) = await _regionAfterWin(reg, e, lines);
          tickets += t;
          lampNow = l;
        }
        // 장소·퀘스트 진행 (발드린)
        if (reg == null) switch (e.kind) {
          case A3Kind.field:
            if (e.place == 'baldrin_ashplain') _sideStep(SideQuest.beacon, lines, '봉화대에 다시 불을 붙였어요');
            if (e.place == 'baldrin_wallroad') _sideStep(SideQuest.roster, lines, '무너진 돌 틈에서 신병 이름표를 찾았어요');
            if (e.place == 'baldrin_wolfhill' &&
                !_act3.has('fur') &&
                _random.nextDouble() < BaldrinRules.furChance) {
              _act3 = _act3.flag('fur');
              lines.add(BaldrinRules.furLine);
            }
          case A3Kind.nest:
            _sideStep(SideQuest.child, lines, '하피 둥지에서 울고 있던 아이를 구했어요');
          case A3Kind.wall:
            _act3 = _act3.flag('wallFought');
            lines.add(BaldrinRules.letterLine);
          case A3Kind.mid:
            if (_act3.quests[SideQuest.dew.name] == 1 && !_act3.has('dew')) {
              _act3 = _act3.flag('dew');
              _sideStep(SideQuest.dew, lines, '사냥개 우리 뒤 숨은 샘에서 빛 이슬을 떠 왔어요');
            }
          case A3Kind.lamp:
            final plates =
                _act3.has('lamp') ? BaldrinRules.plateAgain : BaldrinRules.plateFirst;
            await _grant(0, 0, {MaterialId.hollowPlate: plates},
                over: BagOver.mail, title: '잿빛 빈 갑주 조각');
            lines.add('빈 갑주 조각 $plates개를 얻었어요');
            if (!_act3.has('dungeon')) {
              _act3 = _act3.flag('dungeon');
              tickets += BaldrinRules.dungeonTicket;
            }
            if (!_act3.has('lamp')) {
              _act3 = _act3.flag('lamp');
              tickets += BaldrinRules.lampTickets;
              final t = await _todayRecord();
              await _save(t.copyWith(
                  counters: DailyRecord.addCounts(
                      t.counters, {TitleRules.skyCounter(TitleId.baldrinLamp): 1})));
            }
          case A3Kind.den:
            if (firstDen) {
              _act3 = _act3.flag('denBoss');
              final t = await _todayRecord();
              await _save(t.copyWith(
                  counters: DailyRecord.addCounts(
                      t.counters, {TitleRules.skyCounter(TitleId.windMemory): 1})));
            }
          case A3Kind.floor || A3Kind.event:
            break;
        }
        if (tickets > 0) _act3 = _act3.copyWith(tickets: _act3.tickets + tickets);
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
          lines: lines,
          tickets: tickets,
          lamp: lampNow || (reg == null && e.kind == A3Kind.lamp && tickets >= BaldrinRules.lampTickets),
        );
      });

  /// 동료 다음 레벨까지 경험치
  int allyExpToNext(AllyData a) => Act3Rules.allyExpToNext(a.level);

  Future<void> _saveAct3() =>
      store.saveJson(AppController._act3Key, _act3.toJson());
}
