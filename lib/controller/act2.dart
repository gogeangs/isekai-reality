part of '../app_controller.dart';

/// 분신을 쓰러뜨렸을 때 (결과 화면에 보여 준다)
class AshResult {
  const AshResult({
    required this.won,
    this.firstKill = false,
    this.item,
    this.title,
    this.egg = false,
    this.story,
    this.phasesCleared = 0,
  });

  final bool won;

  /// 처음 쓰러뜨렸는지 (보상은 처음만)
  final bool firstKill;

  /// 받은 유품 장비
  final EquipItem? item;
  final TitleId? title;
  final bool egg;

  /// 왕의 사연 한 조각
  final String? story;

  /// 본체: 이번 싸움까지 걷어낸 감정 단계 수
  final int phasesCleared;
}

/// 2막 (묶음 34): 잿빛 틈 · 분신 다섯 · 본체 · 결말 · 유품 세트
extension Act2Ops on AppController {
  Act2State get act2 => _act2;

  String get _today => DailyRecord.dayKeyOf(_clock());

  /// 지금 지도에 나올 분신 (순서대로, 레벨이 되면). 다 쓰러뜨렸거나 아직이면 null
  AshAvatar? get nextAvatar => _act2Ready && !inTutorial
      ? Act2Rules.nextAvatar(beaten: _act2.beaten, level: player.level.level)
      : null;

  /// 오늘 세 번 다 졌는지 (내일 다시 열림)
  bool get riftClosedToday => _act2.lossesOn(_today) >= Act2Rules.triesPerDay;

  /// 오늘 남은 도전
  int get riftTriesLeft =>
      math.max(0, Act2Rules.triesPerDay - _act2.lossesOn(_today));

  /// 오늘 잿빛 틈 자리 (그날 처음 위치를 잡은 곳 둘레 300~800m, 하루 고정).
  /// 아직 오늘 자리가 없으면 지금 자리로 정한다.
  GeoPoint? get riftPoint {
    final a = nextAvatar;
    if (a == null) return null;
    final day = _today;
    if (_act2.riftDay == day &&
        _act2.riftFor == a.index &&
        _act2.riftLat != null &&
        _act2.riftLng != null) {
      return GeoPoint(_act2.riftLat!, _act2.riftLng!);
    }
    final here = _lastFix?.point ?? (inTutorial ? null : fallbackCenter);
    if (here == null) return null;
    unawaited(_anchorRift(_riftAnchor(day) ?? here));
    // 자리는 바로(저장 전에) 정해진다
    if (_act2.riftDay == day &&
        _act2.riftFor == a.index &&
        _act2.riftLat != null &&
        _act2.riftLng != null) {
      return GeoPoint(_act2.riftLat!, _act2.riftLng!);
    }
    return null;
  }

  /// 그날의 기준 자리 (초반 내 둘레 몬스터와 같은 자리가 있으면 그것)
  GeoPoint? _riftAnchor(String day) => _nearDay == day ? _nearAnchor : null;

  Future<void> _anchorRift(GeoPoint anchor) async {
    final a = nextAvatar;
    if (a == null) return;
    final day = _today;
    if (_act2.riftDay == day && _act2.riftFor == a.index) return;
    // 같은 날 다음 분신으로 넘어가면 기준은 그날 처음 자리 그대로
    final base = _act2.riftDay == day && _act2.riftAnchorLat != null
        ? GeoPoint(_act2.riftAnchorLat!, _act2.riftAnchorLng!)
        : anchor;
    final p = Act2Rules.riftSpot(area,
        dayKey: day,
        anchor: base,
        avatar: a.index,
        roads: roads,
        exclusions: exclusions,
        land: lands?.kindAt);
    _act2 = _act2.copyWith(
      riftDay: day,
      riftFor: a.index,
      riftLat: p.lat,
      riftLng: p.lng,
      riftAnchorLat: base.lat,
      riftAnchorLng: base.lng,
    );
    await _saveAct2();
    _notify();
  }

  /// 위치를 잡을 때: 그날 처음이면 잿빛 틈 자리를 정한다
  Future<void> _riftOnFix(GeoPoint p) async {
    if (nextAvatar == null || _act2.riftDay == _today) return;
    await _anchorRift(p);
  }

  /// 잿빛 틈까지 거리 (m)
  double? get riftDistance {
    final r = riftPoint;
    final f = _lastFix;
    if (r == null || f == null) return null;
    return r.distanceTo(f.point);
  }

  /// 걸어서 잿빛 틈에 닿았는지
  bool get atRift => (riftDistance ?? double.infinity) <= Act2Rules.riftEnterM;

  // ───────────── 분신 전투

  Battle _ashBattle(List<Foe> floors) {
    final p = player;
    _stopResting();
    return _withJob(Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: floors,
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
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
    ));
  }

  /// 잿빛 틈에 들어간다 (걸어서 닿았을 때만, 무료). 못 들어가면 null
  Battle? startAshBattle() {
    final a = nextAvatar;
    if (a == null || riftClosedToday || hp <= 0 || !canFightNow) return null;
    return _ashBattle([Act2Rules.avatarFoe(a, player.level.level)]);
  }

  /// 분신 전투가 끝났을 때. 처음 쓰러뜨리면 유품·칭호·알·왕의 사연
  Future<AshResult> finishAshBattle(Battle battle) => _serial(() async {
        final a = Act2Rules.ofMonster(battle.floors.first.monster);
        if (a == null || !battle.isOver) return const AshResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        final won = battle.phase == BattlePhase.cleared;
        final day = _today;
        if (!won) {
          _act2 = _act2.copyWith(
              lossDay: day, losses: _act2.lossesOn(day) + 1);
          await _saveAct2();
          await _defeated();
          _notify();
          return const AshResult(won: false);
        }
        final first = _act2.beaten == a.id.index;
        final today = await _todayRecord();
        await _save(today.copyWith(
          purifiedMonsterIds: _addMonsters(today, [a.monster]),
          counters: DailyRecord.addCounts(today.counters, {'ashClone': 1}),
        ));
        EquipItem? item;
        var egg = false;
        if (first) {
          item = await _giveRelic(a.gear, a.element);
          egg = await _maybeEgg(1.0, 'ash');
          _act2 = _act2.copyWith(beaten: a.id.index + 1);
          await _saveAct2();
          await gainMastery(Mastery.combat, MasteryRules.dungeonClear);
          _checkAct2();
        }
        _notify();
        return AshResult(
          won: true,
          firstKill: first,
          item: item,
          title: first ? a.title : null,
          egg: egg,
          story: first ? a.story : null,
        );
      });

  /// 유품 장비 한 부위 (가방이 가득해도 잃지 않게 그대로 넣는다)
  Future<EquipItem> _giveRelic(EquipBase base, Element? element) async {
    final a = _armory;
    final grade = EquipmentRules.rollGrade(_random, rare: true);
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      element: element,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      nextId: a.nextId + 1,
    ));
    return item;
  }

  // ───────────── 본체

  /// 분신 다섯을 모두 쓰러뜨려 던전 끝 「문 앞」이 열렸는지 (레벨과 상관없이)
  bool get kingOpen => _act2.beaten >= 5 && !_act2.kingDone;

  /// 본체에 들어간다 (걷어낸 단계부터). HP가 없으면 null
  Battle? startKingBattle() {
    if (!kingOpen || hp <= 0 || !canFightNow) return null;
    return _ashBattle(
        Act2Rules.kingFoes(player.level.level, from: _act2.kingPhase));
  }

  /// 본체 전투가 끝났을 때. 지면 걷어낸 단계를 저장한다
  Future<AshResult> finishKingBattle(Battle battle) => _serial(() async {
        if (!battle.isOver) return const AshResult(won: false);
        await keepBattleHp(battle);
        await _spendBattleBuffs();
        final won = battle.phase == BattlePhase.cleared;
        final cleared = _act2.kingPhase + battle.purified.length;
        if (!won) {
          _act2 = _act2.copyWith(kingPhase: cleared.clamp(0, 4));
          await _saveAct2();
          await _defeated();
          _notify();
          return AshResult(won: false, phasesCleared: _act2.kingPhase);
        }
        final today = await _todayRecord();
        await _save(today.copyWith(
          purifiedMonsterIds: _addMonsters(today, [MonsterId.ashKing]),
          counters: DailyRecord.addCounts(today.counters, {'ashKing': 1}),
        ));
        final item = await _giveRelic(Act2Rules.kingGear, null);
        _act2 = _act2.copyWith(kingPhase: 5, kingDone: true);
        await _saveAct2();
        await gainMastery(Mastery.combat, MasteryRules.dungeonClear);
        _notify();
        return AshResult(
            won: true,
            firstKill: true,
            item: item,
            title: Act2Rules.kingTitle,
            phasesCleared: 5);
      });

  // ───────────── 결말 · 다리 너머

  /// 결말 컷신을 보여 줄 때 (본체를 쓰러뜨린 직후, 도중에 껐으면 다음에 켤 때)
  bool get endingPending => _act2.kingDone && !_act2.endingSeen;

  Future<void> markEndingSeen() async {
    if (_act2.endingSeen) return;
    _act2 = _act2.copyWith(endingSeen: true);
    await _saveAct2();
    _notify();
  }

  /// 「다리 너머 세계가 곧 열려요」를 알릴 때 (결말 뒤 Lv.21 이상)
  bool get bridgePending =>
      _act2.kingDone &&
      _act2.endingSeen &&
      !_act2.bridgeShown &&
      player.level.level >= Act2Rules.bridgeLevel;

  Future<void> markBridgeShown() async {
    _act2 = _act2.copyWith(bridgeShown: true);
    await _saveAct2();
    _notify();
  }

  /// 기록 탭 「왕의 사연」: 쓰러뜨린 분신 순서대로
  List<String> get kingStories => [
        for (var i = 0; i < _act2.beaten && i < Act2Rules.avatars.length; i++)
          Act2Rules.avatars[i].story,
      ];

  // ───────────── 첫 펫 한마디 · 저장

  /// 새 분신의 잿빛 틈이 열리면 첫 펫이 한 번 알린다. 다섯을 다 쓰러뜨리면 「문 앞」
  void _checkAct2() {
    if (!_act2Ready || !_masteryReady || !_pets.farewellDone) return;
    final lines = <String>[];
    var announced = _act2.announced;
    final next = nextAvatar;
    if (next != null && announced <= next.index) {
      announced = next.index + 1;
      lines.add(Act2Rules.riftFirstLine);
    }
    if (_act2.beaten >= 5 && !_act2.kingDone && announced < 6) {
      announced = 6;
      lines.add(Act2Rules.gateOpenLine);
    }
    if (lines.isEmpty) return;
    _act2 = _act2.copyWith(announced: announced);
    _mastery = _mastery.copyWith(pending: [..._mastery.pending, ...lines]);
    unawaited(_saveMastery());
    unawaited(_saveAct2());
  }

  Future<void> _saveAct2() =>
      store.saveJson(AppController._act2Key, _act2.toJson());
}
