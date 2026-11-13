part of '../app_controller.dart';

/// 연금술 공방·물약·변환·가공 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension AlchemyOps on AppController {

  AlchemyState get alchemy => _alc;

  Future<void> _saveAlc(AlchemyState a) async {
    _alc = a;
    await store.saveJson(AppController._alchemyKey, a.toJson());
    _notify();
  }

  /// 가방 칸을 쓰는 그 밖의 것 (나중에 더할 자리)
  List<int> _extraBagCounts() => [_gather.pouches];

  /// 읽지 않은 레시피 쪽지
  int get recipeNotes => _pets.recipeNotes;

  Future<void> _maybeNote(double chance) async {
    if (_random.nextDouble() >= chance) return;
    await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
  }

  /// 레시피 책에 보이는 물약 (처음부터 공개 + 발견 + 쪽지)
  List<PotionId> get knownRecipes => [
        for (final p in AlchemyRules.all)
          if (p.public ||
              _alc.discovered.contains(p.id.name) ||
              _alc.noted.contains(p.id.name))
            p.id,
      ];

  /// 재료·개수를 아는지 (쪽지로만 알면 아직 만들어 보지 않은 것)
  bool recipeDiscovered(PotionId id) =>
      AlchemyRules.info(id).public || _alc.discovered.contains(id.name);

  /// 쪽지를 읽는다: 아직 모르는 물약 하나의 재료·개수 (순서는 빼고)
  Future<PotionId?> readNote() async {
    if (_pets.recipeNotes <= 0) return null;
    final unknown = [
      for (final p in AlchemyRules.all)
        if (!p.public &&
            !_alc.discovered.contains(p.id.name) &&
            !_alc.noted.contains(p.id.name))
          p.id,
    ];
    if (unknown.isEmpty) return null;
    final id = unknown[_random.nextInt(unknown.length)];
    await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes - 1));
    await _saveAlc(_alc.copyWith(noted: [..._alc.noted, id.name]));
    return id;
  }

  /// 다음 가마솥 값 (더 살 수 없으면 null)
  int? get cauldronGold => AlchemyRules.cauldronGold(_alc.cauldrons);
  int get cauldronStone => AlchemyRules.cauldronStone(_alc.cauldrons);

  Future<bool> buyCauldron() async {
    final gold = cauldronGold;
    final stone = cauldronStone;
    if (gold == null || player.gold < gold) return false;
    if (player.materialCount(MaterialId.labyrinthStone) < stone) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
      Wallet.gold: gold,
      if (stone > 0) MaterialId.labyrinthStone.name: stone,
    })));
    await _saveAlc(_alc.copyWith(cauldrons: _alc.cauldrons + 1));
    return true;
  }

  /// 가마솥 [slot] 에 재료를 넣고 끓인다 (넣은 순서가 중요)
  Future<bool> startBrew(int slot, List<MaterialId> put) async {
    if (slot < 0 || slot >= _alc.cauldrons || _alc.brews.containsKey(slot)) {
      return false;
    }
    if (put.isEmpty || put.length > AlchemyRules.maxIngredients) return false;
    final need = <MaterialId, int>{};
    for (final m in put) {
      need[m] = (need[m] ?? 0) + 1;
    }
    for (final e in need.entries) {
      if (player.materialCount(e.key) < e.value) return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {for (final e in need.entries) e.key.name: e.value})));
    final match = AlchemyRules.match(put);
    final minutes = match == null
        ? AlchemyRules.suspiciousMinutes
        : AlchemyRules.info(match.id).minutes;
    final now = _clock();
    final ready = now.add(Duration(minutes: minutes));
    await _saveAlc(_alc.copyWith(brews: {
      ..._alc.brews,
      slot: Brew(put: [for (final m in put) m.name], startedAt: now, readyAt: ready),
    }));
    unawaited(notifier?.schedule(
        200 + slot, ready, '물약이 다 끓었어요', '연금술 공방에서 가마솥을 확인해 보세요!'));
    return true;
  }

  bool brewReady(int slot) {
    final b = _alc.brews[slot];
    return b != null && !_clock().isBefore(b.readyAt);
  }

  /// 다 끓은 물약을 꺼낸다
  Future<BrewResult?> collectBrew(int slot) async {
    final b = _alc.brews[slot];
    if (b == null || !brewReady(slot)) return null;
    final put = [
      for (final n in b.put)
        if (Materials.byName(n) case final m?) m,
    ];
    final brews = {..._alc.brews}..remove(slot);
    var a = _alc.copyWith(brews: brews);
    final match = AlchemyRules.match(put);
    BrewResult result;
    if (match == null) {
      final key = '?:${AlchemyRules.comboKey(put)}';
      a = a.add(key, 1);
      result = BrewResult(suspicious: key, count: 1);
    } else {
      final info = AlchemyRules.info(match.id);
      final isNew = !recipeDiscovered(match.id);
      // 품질 3등급 (11-11 #74): 숙련도 보너스는 연금술사 직업 각성 뒤에 더한다
      final q = AlchemyRules.quality(perfect: match.perfect, put: put);
      a = a.copyWith(
          mastery: a.mastery +
              AlchemistRules.brewPoints +
              (q == PotionQuality.best ? AlchemistRules.bestBonusPoints : 0));
      if (info.shopItem != null && q == PotionQuality.normal) {
        // 잡화상과 같은 물약은 같은 물건으로 가방에
        final today = await _todayRecord();
        await _save(today.copyWith(
            counters: DailyRecord.addCounts(today.counters,
                {TownRules.giftKey(info.shopItem!): info.yields})));
      } else {
        a = a.add(AlchemyRules.keyOf(match.id, q), info.yields);
      }
      if (isNew) a = a.copyWith(discovered: [...a.discovered, match.id.name]);
      result = BrewResult(
          potion: match.id,
          perfect: match.perfect,
          quality: q,
          count: info.yields,
          discovered: isNew);
    }
    await _saveAlc(a);
    return result;
  }

  // ───────────── 물약 이름·효과

  /// 공방 물약 키 → 이름
  String potionName(String key) {
    if (key.startsWith('?:')) return '수상한 물약';
    final k = AlchemyRules.parseKey(key);
    if (k == null) return key;
    // 품질 (11-11 #74): 좋음·최상만 이름에 붙인다
    return '${AlchemyRules.info(k.id).name}'
        '${k.quality == PotionQuality.normal ? '' : ' (${k.quality.label})'}';
  }

  String potionDescription(String key) {
    if (key.startsWith('?:')) {
      if (!_alc.knownSuspicious.contains(key)) return '마시기 전에는 무슨 효과인지 몰라요.';
      final e = AlchemyRules.suspiciousEffect(_putOf(key));
      return e.stat == null
          ? '마시면 HP가 ${e.amount}% 차요. (수상한 물약)'
          : '10분 동안 ${e.stat!.label} +${e.amount}. (수상한 물약)';
    }
    final k = AlchemyRules.parseKey(key);
    if (k == null) return '';
    return '${AlchemyRules.info(k.id).description} 품질: ${k.quality.label}'
        '${k.quality == PotionQuality.normal ? '' : ' (효과가 더 크고 오래가요)'}';
  }

  List<MaterialId> _putOf(String key) => [
        for (final n in key.substring(2).split('+'))
          if (Materials.byName(n) case final m?) m,
      ];

  /// 원정 MP가 [need] 만큼 모자랄 때 마실 수 있는 마나 물약 (11-11 #64).
  /// 한 병으로 채우는 가장 작은 물약이 먼저, 한 병으로 안 되면 적은 병 수부터.
  List<ManaOption> manaOptions(int need) {
    if (need <= 0) return const [];
    final out = <ManaOption>[];
    for (final item in const [ShopItem.manaSmall, ShopItem.mana]) {
      final n = bagCount(item);
      if (n <= 0) continue;
      final per = math.max(1, (mpMax * TownRules.info(item).mpRatio).round());
      out.add(ManaOption(
          name: itemName(item), count: n, perBottle: per,
          bottles: (need / per).ceil(), item: item));
    }
    for (final e in _alc.potions.entries) {
      final info = _infoOf(e.key);
      if (info == null || info.kind != PotionKind.mana || e.value <= 0) continue;
      final m = _qualityMult(e.key);
      final per = math.max(1, (mpMax * info.mpRatio * m).round());
      out.add(ManaOption(
          name: potionName(e.key), count: e.value, perBottle: per,
          bottles: (need / per).ceil(), key: e.key));
    }
    out.sort((a, b) {
      final c = a.bottles.compareTo(b.bottles);
      return c != 0 ? c : a.perBottle.compareTo(b.perBottle);
    });
    return out;
  }

  /// [o] 를 한 병 마신다
  Future<bool> drinkMana(ManaOption o) async {
    if (o.item != null) return await useItem(o.item!) == UseCheck.ok;
    return await drinkPotion(o.key!) == null;
  }

  PotionInfo? _infoOf(String key) {
    final k = AlchemyRules.parseKey(key);
    return k == null ? null : AlchemyRules.info(k.id);
  }

  /// 품질 배율 (보통 1, 좋음 1.25, 최상 1.5)
  double _qualityMult(String key) =>
      AlchemyRules.parseKey(key)?.quality.mult ?? 1.0;

  /// 전투에 가져가는 회복·상태이상 물약 (잡화상 물약 + 공방 물약)
  List<BattlePotion> get battlePotions {
    final out = <BattlePotion>[];
    for (final item in [ShopItem.healSmall, ShopItem.heal]) {
      final n = bagCount(item);
      if (n > 0) {
        out.add(BattlePotion(
            key: 'shop:${item.name}',
            name: TownRules.info(item).name,
            count: n,
            hpRatio: TownRules.info(item).hpRatio));
      }
    }
    for (final e in _alc.potions.entries) {
      final info = _infoOf(e.key);
      if (info == null) continue;
      final m = _qualityMult(e.key);
      final cure = switch (info.id) {
        PotionId.antidote => CureKind.poison,
        PotionId.burnSalve => CureKind.burn,
        PotionId.clearEye => CureKind.dazzle,
        PotionId.thaw => CureKind.freeze,
        _ => null,
      };
      if (cure == null && info.hpRatio <= 0) continue;
      out.add(BattlePotion(
          key: 'alc:${e.key}',
          name: potionName(e.key),
          count: e.value,
          hpRatio: info.hpRatio * m,
          cure: cure));
    }
    return out;
  }

  /// 전투에서 마신 물약을 가방에서 뺀다 (한 번만)
  Future<void> _consumeBattlePotions(Battle battle) async {
    if (battle.potionsUsed.isEmpty || _consumed[battle] == true) return;
    _consumed[battle] = true;
    var a = _alc;
    final used = <String>[];
    battle.potionsUsed.forEach((key, n) {
      if (key.startsWith('shop:')) {
        for (var i = 0; i < n; i++) {
          used.add(key.substring(5));
        }
      } else if (key.startsWith('alc:')) {
        a = a.add(key.substring(4), -n);
      }
    });
    if (used.isNotEmpty) {
      final today = await _todayRecord();
      await _save(today.copyWith(itemsUsed: [...today.itemsUsed, ...used]));
    }
    await _saveAlc(a);
  }

  Future<String?> drinkPotion(String key) async {
    drinkNote = null;
    if (_alc.count(key) <= 0) return '가방에 없어요';
    final now = _clock();
    final buffs = [for (final b in _alc.buffs) if (_buffActive(b, now)) b];
    var a = _alc.copyWith(buffs: buffs);
    if (key.startsWith('?:')) {
      final e = AlchemyRules.suspiciousEffect(_putOf(key));
      if (e.stat == null) {
        await refreshVitals();
        _vitals = _vitals.copyWith(
            hp: math.min(maxHp, hp + (maxHp * e.amount / 100).round()),
            lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      } else {
        a = a.copyWith(buffs: [
          for (final b in a.buffs)
            if (!b.key.startsWith('?:')) b,
          ActiveBuff(
              key: '?:${e.stat!.name}',
              until: now.add(AlchemyRules.suspiciousDuration),
              amount: e.amount),
        ]);
      }
      a = a.add(key, -1).copyWith(knownSuspicious: {
        ...a.knownSuspicious,
        key,
      }.toList());
      await _saveAlc(a);
      return null;
    }
    final info = _infoOf(key);
    if (info == null) return '알 수 없는 물약이에요';
    final m = _qualityMult(key);
    Duration dur(Duration d) => Duration(seconds: (d.inSeconds * m).round());
    final battles = (info.battles * m).round();
    ActiveBuff? next;
    switch (info.kind) {
      case PotionKind.heal:
        await refreshVitals();
        if (hp >= maxHp) return '이미 가득해요';
        _vitals = _vitals.copyWith(
            hp: math.min(maxHp, hp + (maxHp * info.hpRatio * m).round()),
            lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      case PotionKind.mana:
        await refreshVitals();
        if (mp >= mpMax) return '이미 가득해요';
        _vitals = _vitals.copyWith(
            mp: math.min(mpMax, mp + (mpMax * info.mpRatio * m).round()));
        await store.saveVitals(_vitals);
      case PotionKind.care:
        return '전투 중에만 마실 수 있어요';
      case PotionKind.buff:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles,
            amount: (AlchemyRules.buffStat * m).round());
      case PotionKind.resist:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles,
            amount: (AlchemyRules.resistCut * 100 * m).round());
      case PotionKind.weapon:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles);
      case PotionKind.special:
        switch (info.id) {
          case PotionId.plenty:
            next = ActiveBuff(
                key: 'plenty', until: now.add(dur(info.duration)));
          case PotionId.steps:
            final today = await _todayRecord();
            next = ActiveBuff(
              key: info.id.name,
              until: DateTime(now.year, now.month, now.day + 1),
              day: today.dayKey,
              stepsFrom: today.steps,
              stepsCap: (info.steps * m).round(),
              amount: TownRules.gaugeBonusOn(today),
            );
          case PotionId.callMonsters || PotionId.callModified:
            final day = player.today?.dayKey ?? '';
            final already = a.calledDays[info.id.name] == day;
            // 11-11 A3: 유인 물약은 하루 1번만 부르고, 채집 자리 1.5배는 마실 때마다 다시
            if (already && info.id != PotionId.callMonsters) {
              return '오늘은 이미 불렀어요';
            }
            if (already) {
              drinkNote = '오늘은 이미 불렀어요. 채집 자리만 늘었어요.';
            } else {
              final center = _lastFix?.point;
              if (center == null) return '위치를 켜 주세요';
              a = a.copyWith(
                calledDays: {...a.calledDays, info.id.name: day},
                called: [
                  for (final c in a.called)
                    if (c.id.startsWith(day)) c,
                  ..._callSpawns(center, day, info.id == PotionId.callModified,
                      a.called.length),
                ],
              );
            }
            // 유인 물약 (11-11 #74): 30분 동안 채집 자리 1.5배
            if (info.id == PotionId.callMonsters) {
              next = ActiveBuff(
                  key: info.id.name, until: now.add(dur(info.duration)));
            }
          default:
            return '지금은 마실 수 없어요';
        }
    }
    if (next != null) {
      // 같은 종류는 새 물약으로 바뀐다
      final slot = info.slot;
      a = a.copyWith(buffs: [
        for (final b in a.buffs)
          if (_slotOf(b) != slot) b,
        next,
      ]);
      _spotsKey = null; // 유인 물약이면 채집 자리를 다시 만든다
    }
    await _saveAlc(a.add(key, -1));
    return null;
  }

  /// 물약 효과가 아직 남았는지 (전투 수 · 걸음 · 시간)
  bool _buffActive(ActiveBuff b, [DateTime? at]) {
    if (b.battles != null) return b.battles! > 0;
    if (b.stepsCap != null) {
      final today = player.today;
      if (today == null || b.day != today.dayKey) return false;
      return today.steps - (b.stepsFrom ?? 0) < b.stepsCap!;
    }
    return b.until.isAfter(at ?? _clock());
  }

  /// 걸린 물약의 종류 (수상한 물약은 따로)
  PotionSlot? _slotOf(ActiveBuff b) {
    final id = AlchemyRules.byName(b.key);
    return id == null ? null : AlchemyRules.info(id).slot;
  }

  /// 전투·속성 물약은 전투가 끝날 때마다 남은 횟수가 하나 준다 (11-11 #74)
  Future<void> _spendBattleBuffs() async {
    if (!_alc.buffs.any((b) => b.battles != null)) return;
    await _saveAlc(_alc.copyWith(buffs: [
      for (final b in _alc.buffs)
        if (b.battles == null)
          b
        else if (b.battles! > 1)
          b.withBattles(b.battles! - 1),
    ]));
  }

  /// 걸음 물약 효과 설명 (남은 전투 · 걸음 · 시간)
  String buffLeftLabel(ActiveBuff b) {
    if (b.battles != null) return '전투 ${b.battles}번 남음';
    if (b.stepsCap != null) {
      final walked = (player.today?.steps ?? 0) - (b.stepsFrom ?? 0);
      return '${comma(math.max(0, b.stepsCap! - walked))}보 남음';
    }
    final left = b.until.difference(_clock()).inMinutes;
    return '${math.max(1, left)}분 남음';
  }

  /// 걸린 물약의 이름 (수상한 물약은 스탯)
  String buffName(ActiveBuff b) {
    if (b.key.startsWith('?:')) return '수상한 물약';
    final id = AlchemyRules.byName(b.key);
    return id == null ? b.key : AlchemyRules.info(id).name;
  }

  /// 공격 속성 물약의 속성 (없으면 null)
  Element? get weaponPotionElement {
    for (final b in activeBuffs) {
      final id = AlchemyRules.byName(b.key);
      if (id == null) continue;
      final info = AlchemyRules.info(id);
      if (info.kind == PotionKind.weapon) return info.element;
    }
    return null;
  }

  /// 유인 물약이 걸려 있는지 (채집 자리 1.5배)
  bool get lureActive => activeBuffs.any((b) => b.key == PotionId.callMonsters.name);

  List<CalledSpawn> _callSpawns(
      GeoPoint center, String day, bool modified, int start) {
    final n = modified ? AlchemyRules.callModCount : AlchemyRules.callCount;
    final out = <CalledSpawn>[];
    for (var i = 0; i < n; i++) {
      final r = AlchemyRules.callRadiusM * math.sqrt(_random.nextDouble());
      final t = _random.nextDouble() * 2 * math.pi;
      final lat = center.lat + r * math.cos(t) / 111320.0;
      final lng = center.lng +
          r * math.sin(t) / (111320.0 * math.cos(center.lat * math.pi / 180));
      final monster = FieldMonsterRules.pickCommon(
          _random.nextDouble(), _random.nextDouble(),
          night: FieldMonsterRules.isNight(_clock()));
      final mods = <String>[];
      if (modified) {
        final grade = _random.nextDouble() < AlchemyRules.callModRareChance
            ? ModGrade.rare
            : ModGrade.common;
        mods.add(ModifierRules.pick(grade, monster, _random).name);
      }
      out.add(CalledSpawn(
          id: '$day#call${start + i}',
          monster: monster.name,
          lat: lat,
          lng: lng,
          mods: mods));
    }
    return out;
  }

  /// 부르는 물약으로 나온 오늘의 몬스터
  List<FieldSpawn> get calledSpawns {
    final day = player.today?.dayKey ?? '';
    return [
      for (final c in _alc.called)
        if (c.id.startsWith(day))
          if (Monsters.byName(c.monster) case final m?)
            FieldSpawn(
              id: c.id,
              monster: m,
              point: GeoPoint(c.lat, c.lng),
              modifiers: [
                for (final n in c.mods)
                  if (ModifierRules.byName(n) case final x?) x,
              ],
            ),
    ];
  }

  /// 지금 걸린 버프·저항
  List<ActiveBuff> get activeBuffs =>
      [for (final b in _alc.buffs) if (_buffActive(b)) b];

  /// 물약 버프로 더해지는 스탯
  Stats get buffStats {
    var st = Stats.zero;
    for (final b in activeBuffs) {
      final name = b.key.startsWith('?:') ? b.key.substring(2) : null;
      final id = name == null ? AlchemyRules.byName(b.key) : null;
      final kind = name != null
          ? StatKindInfo.parse(name)
          : (id == null ? null : AlchemyRules.info(id).stat);
      if (kind == null) continue;
      st = st + Stats.zero.withValue(kind, b.amount);
    }
    return st;
  }

  Map<Element, double> get activeResists => {
        for (final b in activeBuffs)
          if (AlchemyRules.byName(b.key) case final id?)
            if (AlchemyRules.info(id).kind == PotionKind.resist)
              if (AlchemyRules.info(id).element case final el?) el: b.amount / 100,
      };

  bool get plentyActive => activeBuffs.any((b) => b.key == 'plenty');

  // ───────────── 공방 변환 (11-11 #74)

  /// 변환대에서 진행 중인 것 (없으면 null)
  ConvertJob? get convertJob => _alc.convert;

  bool get convertReady {
    final j = _alc.convert;
    return j != null && !_clock().isBefore(j.readyAt);
  }

  /// 연금술사 숙련도 단계 (직업 각성 뒤에 효과가 생긴다)
  AlchemistRank get alchemistRank => AlchemistRules.rankOf(_alc.mastery);

  /// 변환할 수 있는지 (금화·재료·마석·물약, 시간이 드는 변환은 변환대가 비어야 한다)
  bool canConvert(ConvertPlan p) {
    if (p.minutes > 0 && _alc.convert != null) return false;
    if (player.gold < p.gold || player.manaStones < p.giveManaStones) return false;
    for (final e in p.give.entries) {
      if (player.materialCount(e.key) < e.value) return false;
    }
    if (p.givePotion != null && _alc.count(p.givePotion!) <= 0) return false;
    return true;
  }

  /// 변환을 시작한다. 분해는 바로 끝난다.
  Future<bool> startConvert(ConvertPlan p) async {
    if (!canConvert(p)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        for (final e in p.give.entries) e.key.name: e.value,
        if (p.gold > 0) Wallet.gold: p.gold,
        if (p.giveManaStones > 0) Wallet.manaStone: p.giveManaStones,
      }),
    ));
    var a = _alc;
    if (p.givePotion != null) a = a.add(p.givePotion!, -1);
    if (p.minutes == 0) {
      await _saveAlc(a);
      await _grant(0, p.getManaStones, p.get);
      return true;
    }
    final now = _clock();
    final ready = now.add(Duration(minutes: p.minutes));
    await _saveAlc(a.copyWith(
      mastery: a.mastery + AlchemistRules.convertPoints,
      convert: ConvertJob(
        kind: p.kind.name,
        get: {for (final e in p.get.entries) e.key.name: e.value},
        getManaStones: p.getManaStones,
        startedAt: now,
        readyAt: ready,
      ),
    ));
    unawaited(notifier?.schedule(
        260, ready, '변환이 끝났어요', '연금술 공방 변환대에서 꺼내 가세요!'));
    return true;
  }

  /// 다 된 변환을 꺼낸다
  Future<ConvertJob?> collectConvert() async {
    final j = _alc.convert;
    if (j == null || !convertReady) return null;
    await _saveAlc(_alc.copyWith(clearConvert: true));
    await _grant(0, j.getManaStones, {
      for (final e in j.get.entries)
        if (Materials.byName(e.key) case final m?) m: e.value,
    });
    return j;
  }

  // ───────────── 재료 가공 (11-11 #59)

  bool canProcess(ProcessRecipe r) =>
      player.gold >= r.gold && ProcessRules.use(r, player.materials) != null;

  /// 하위 재료를 상위 재료로 바꾼다 (바로 끝남)
  Future<bool> process(ProcessRecipe r) async {
    final use = ProcessRules.use(r, player.materials);
    if (use == null || player.gold < r.gold) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        for (final e in use.entries) e.key.name: e.value,
        if (r.gold > 0) Wallet.gold: r.gold,
      }),
      gains: DailyRecord.addCounts(today.gains, {r.output.name: r.count}),
    ));
    return true;
  }

  /// 공방 물약을 버린다
  Future<bool> discardPotion(String key, int n) async {
    if (_alc.count(key) < n || n <= 0) return false;
    await _saveAlc(_alc.add(key, -n));
    return true;
  }

  /// 자동 마시기 설정
  Future<void> setAutoUse({int? hpPercent, bool? cure}) async =>
      _saveAlc(_alc.copyWith(autoHp: hpPercent, autoCure: cure));
}
