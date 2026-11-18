part of '../app_controller.dart';

/// 3막 지역 2~5 (묶음 57 #243): 발드린과 같은 틀을 [RegionContent] 하나로 돌린다.
/// 기록은 [Act3State] 안에 지역 이름을 붙여 둔다 (새 저장 칸 없음 · 예전 기록 그대로):
/// flags '<지역>:first' ① · ':talk' ② · ':event' ③ 싸움 · ':choice:<옵션>' · ':lamp' · ':dungeon' ·
/// ':hidden' 숨은 장소 열림 · ':hiddenBoss' · ':weapon' · 'reach:<지역>' 도착 · 'act3End' 3막 끝.
/// prog '<지역>:floorBest' · ':floorNow' · ':deepBest' (심층) · 'sel:auction' (경매 날)
extension Act3RegionsOps on AppController {
  // ───────────── 지금 지역 · 길 · 자유 이동

  /// 지금 지역의 내용 (발드린이면 null)
  RegionContent? get regionNow => RegionRules.of(currentRegion.id);

  String _rk(RegionContent r, String k) => '${r.prefix}:$k';
  bool _rh(RegionContent r, String k) => _act3.has(_rk(r, k));

  /// 그 지역 등불을 켰는지 (발드린 포함)
  bool regionLit(Region r) =>
      r == Region.baldrin ? baldrinLit : _act3.has('${r.name}:lamp');

  /// 가 본 지역 (발드린은 늘)
  bool regionReached(Region r) => r == Region.baldrin || _act3.has('reach:${r.name}');

  /// 다섯 등불을 모두 켜고 3막 끝 장면까지 봤는지 → 자유 이동 · 심층
  bool get act3Done => _act3.has('act3End');

  /// 3막 끝 장면을 볼 차례 (아우렐 등불 + 큰 고르기 뒤)
  bool get act3EndPending =>
      !act3Done && regionLit(Region.aurel) && regionChoice(RegionRules.aurel) != null;

  /// 다음 지역으로 들어갈 수 있는지 (지금 지역 등불 · 길 걸음 · 레벨)
  bool get canEnterNext {
    final r = road;
    return r.next != null &&
        r.levelOk &&
        r.steps >= r.need &&
        regionLit(currentRegion.id) &&
        !regionReached(r.next!.id);
  }

  /// 다음 지역으로 (길 걸음은 그만큼 씀). 들어간 지역의 내용
  Future<RegionContent?> enterNextRegion() => _serial(() async {
        if (!canEnterNext) return null;
        final next = road.next!;
        _act3 = _act3.copyWith(
          region: next.id.index,
          roadSteps: math.max(0, _act3.roadSteps - Act3Rules.roadSteps),
          flags: {..._act3.flags, 'reach:${next.id.name}'},
        );
        _ember(next.id);
        await _saveAct3();
        _notify();
        return RegionRules.of(next.id);
      });

  /// 3막이 끝난 뒤 가 본 지역끼리 자유롭게 오감
  bool canTravelTo(Region r) =>
      act3Done && regionReached(r) && r.index != _act3.region;

  Future<bool> travelTo(Region r) => _serial(() async {
        if (!canTravelTo(r)) return false;
        _act3 = _act3.copyWith(region: r.index);
        _ember(r);
        await _saveAct3();
        _notify();
        return true;
      });

  /// 지역에 처음 들어간 장면을 볼 차례 (동료 합류)
  bool regionArrivePending(RegionContent r) => !_rh(r, 'arrive');

  Future<void> markRegionArrive(RegionContent r) => _serial(() async {
        if (_rh(r, 'arrive')) return;
        _act3 = _act3.flag(_rk(r, 'arrive'));
        for (final e in r.joins.entries) {
          if (e.value == 'arrive') _joinStory(e.key);
        }
        await _saveAct3();
        _notify();
      });

  /// 이야기 동료 합류 (이미 있으면 그대로)
  void _joinStory(StoryAlly a) {
    if (_act3.ally(a.name) != null) return;
    final lv = math.max(1, player.level.level - 1);
    final info = Act3Rules.story(a);
    _act3 = _act3.copyWith(allies: [
      ..._act3.allies,
      AllyData(id: a.name, story: a.name, name: info.name, stats: info.stats, level: lv, joinLevel: lv),
    ]);
  }

  bool storyJoined(StoryAlly a) => _act3.ally(a.name) != null;

  // ───────────── 메인 흐름

  /// 0 ① 첫 장소 싸움 · 1 ② 마을 이야기 · 2 ③ 사건(+고르기) · 3 ④ 던전 · 4 ⑤ 등불 · 5 끝
  int regionStep(RegionContent r) {
    if (!_rh(r, 'first')) return 0;
    if (!_rh(r, 'talk')) return 1;
    if (r.choice.afterLamp ? !_rh(r, 'event') : regionChoice(r) == null) return 2;
    if (regionFloorBest(r) < 4) return 3;
    if (!_rh(r, 'lamp')) return 4;
    return 5;
  }

  List<({String title, String text, bool done, String? place})> regionJournal(RegionContent r) {
    final step = regionStep(r);
    return [
      for (final (i, m) in r.mains.indexed)
        if (i <= step) (title: m.title, text: m.text, done: i < step, place: m.place),
    ];
  }

  bool regionTalkPending(RegionContent r) => _rh(r, 'first') && !_rh(r, 'talk');

  Future<void> markRegionTalk(RegionContent r) => _serial(() async {
        if (_rh(r, 'talk')) return;
        _act3 = _act3.flag(_rk(r, 'talk'));
        await _saveAct3();
        _notify();
      });

  /// ③ 사건 싸움을 할 차례
  bool regionEventPending(RegionContent r) => _rh(r, 'talk') && !_rh(r, 'event');

  A3Enc regionEventFight(RegionContent r) => A3Enc(
      kind: A3Kind.event,
      foes: r.eventFoes,
      place: r.eventPlace,
      energy: Act3Rules.energyField,
      background: Act3Rules.place(r.eventPlace)?.background);

  /// 고른 옵션 키 (아직이면 null)
  String? regionChoice(RegionContent r) {
    for (final o in [r.choice.a, r.choice.b]) {
      if (_rh(r, 'choice:${o.key}')) return o.key;
    }
    return null;
  }

  bool regionChoicePending(RegionContent r) =>
      regionChoice(r) == null && (r.choice.afterLamp ? _rh(r, 'lamp') : _rh(r, 'event'));

  /// 큰 고르기 (한 번 고르면 바꿀 수 없음). 고르며 받은 장비
  Future<EquipItem?> chooseRegion(RegionContent r, ROption o) => _serial(() async {
        if (!regionChoicePending(r)) return null;
        _act3 = _act3.flag(_rk(r, 'choice:${o.key}'));
        for (final e in r.joins.entries) {
          if (e.value.split('|').contains('choice:${o.key}')) _joinStory(e.key);
        }
        if (o.tickets > 0) _act3 = _act3.copyWith(tickets: _act3.tickets + o.tickets);
        if (o.gold > 0) await _grant(o.gold, 0, const {});
        EquipItem? item;
        if (o.unique case final u?) item = await _a3Gear(u, rare: true);
        await _saveAct3();
        _notify();
        return item;
      });

  // ───────────── 주민 · 퀘스트

  String regionResidentLine(RegionContent r, RResident p) {
    final key = 'met:${r.prefix}:${p.id}';
    if (!_act3.has(key)) {
      _act3 = _act3.flag(key);
      unawaited(_saveAct3());
      return p.first;
    }
    final n = (_a3Talk['${r.prefix}:${p.id}'] ?? 0) + 1;
    _a3Talk['${r.prefix}:${p.id}'] = n;
    if (_rh(r, 'lamp') && p.afterLamp != null && n.isOdd) return p.afterLamp!;
    return p.lines[n % p.lines.length];
  }

  int questState(RQuest q) => _act3.quests[q.id] ?? 0;
  int questProg(RQuest q) => _act3.prog[q.id] ?? 0;
  bool questReady(RQuest q) =>
      questState(q) == 1 &&
      questProg(q) >= (q.kind == RQKind.floor || q.kind == RQKind.boss ? 1 : q.target) &&
      (!q.embers || embersFound >= RegionRules.embersNeed);

  /// 묶음 58: 테스 퀘스트 불씨 — 받은 뒤 지역에 들어갈 때(처음이든 다시든) 그 지역 하나씩
  int get embersFound => [for (final r in Region.values) if (_act3.has('ember:${r.name}')) r].length;

  void _ember(Region r) {
    final q = RegionRules.aurel.quest('aur_record');
    if (questState(q) == 1 && !_act3.has('ember:${r.name}')) _act3 = _act3.flag('ember:${r.name}');
  }

  /// 주민이 맡길 퀘스트 (② 이야기 뒤)
  RQuest? regionOffer(RegionContent r, RResident p) {
    if (!_rh(r, 'talk')) return null;
    for (final q in r.quests) {
      if (q.giver == p.id && questState(q) == 0) return q;
    }
    return null;
  }

  /// 의뢰판에 붙는 동료의 부탁 (그 동료가 합류했으면)
  List<RQuest> regionAllyOffers(RegionContent r) => [
        for (final q in r.quests)
          if (q.ally != null && storyJoined(q.ally!) && _rh(r, 'talk') && questState(q) == 0) q,
      ];

  Future<void> acceptQuest(RQuest q) => _serial(() async {
        if (questState(q) != 0) return;
        _act3 = _act3.copyWith(quests: {..._act3.quests, q.id: 1}, prog: {..._act3.prog, q.id: 0});
        if (q.embers) _ember(currentRegion.id);
        await _saveAct3();
        _notify();
      });

  void _questStep(RQuest q, List<String> lines, {int by = 1}) {
    if (questState(q) != 1) return;
    final t = q.kind == RQKind.floor || q.kind == RQKind.boss ? 1 : q.target;
    final now = questProg(q);
    if (now >= t) return;
    final next = math.min(t, now + by);
    _act3 = _act3.copyWith(prog: {..._act3.prog, q.id: next});
    if (q.line.isNotEmpty) lines.add(t > 1 ? '${q.line} ($next/$t)' : q.line);
  }

  /// 퀘스트 보고: 모집권 1 + 금화 (동료 퀘스트는 스킬 ④ · 숨은 장소가 열리기도)
  Future<bool> reportQuest(RegionContent r, RQuest q) => _serial(() async {
        if (!questReady(q)) return false;
        await _grant(RegionRules.sideGold, 0, const {});
        _act3 = _act3.copyWith(
          quests: {..._act3.quests, q.id: 2},
          tickets: _act3.tickets + RegionRules.sideTickets,
        );
        if (r.hidden.unlockBy == q.id) _act3 = _act3.flag(_rk(r, 'hidden'));
        await _saveAct3();
        await _count('act3Side');
        _notify();
        return true;
      });

  /// 이야기 동료 스킬 ④ (리안은 늘 · 가렌은 「신병 다섯의 명부」 · 나머지는 지역 동료 퀘스트)
  bool allyQuestDone(StoryAlly a) {
    if (a == StoryAlly.lian) return true;
    if (a == StoryAlly.garen) return garenRosterDone;
    for (final r in RegionRules.all) {
      for (final q in r.quests) {
        if (q.ally == a) return questState(q) == 2;
      }
    }
    return false;
  }

  /// 걷기 퀘스트에 걸음을 더함 (_act3Walk 에서)
  void _regionWalk(int delta) {
    if (delta <= 0) return;
    for (final r in RegionRules.all) {
      for (final q in r.quests) {
        if (q.kind == RQKind.walk && questState(q) == 1 && questProg(q) < q.target) {
          _act3 = _act3.copyWith(
              prog: {..._act3.prog, q.id: math.min(q.target, questProg(q) + delta)});
        }
      }
    }
  }

  // ───────────── 마을 가게 · 경매장 (셀레니아)

  /// 등불 전 셀레니아는 흑등 상회 빛 가게만 (값 두 배)
  bool regionShopDark(RegionContent r) => r.shopDark && !_rh(r, 'lamp');

  List<ShopItem> regionShopItems(RegionContent r) => [
        ...r.shop,
        if (_rh(r, 'lamp')) ...r.shopMore,
      ];

  int regionPrice(RegionContent r, ShopItem item) {
    final p = TownRules.info(item).price;
    return regionShopDark(r) ? (p * RegionRules.darkPrice).round() : p;
  }

  /// 마을 가게에서 산다 (흑등 상회는 웃돈을 더 냄)
  Future<PurchaseCheck> regionBuy(RegionContent r, ShopItem item) async {
    final extra = regionPrice(r, item) - TownRules.info(item).price;
    if (extra > 0 && player.gold < regionPrice(r, item)) return PurchaseCheck.notEnoughCrystals;
    final res = await buy(item);
    if (res == PurchaseCheck.ok && extra > 0) {
      await _serial(() async {
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {Wallet.gold: extra})));
        _notify();
      });
    }
    return res;
  }

  int get _dayNo {
    final d = _clock();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// 셀레니아 경매장: 오늘의 물건 (날마다 바뀜, 하루 한 번). 등불 전 · 이미 샀으면 null
  EquipBase? get auctionLot {
    final r = RegionRules.selenia;
    if (!_rh(r, 'lamp') || (_act3.prog['sel:auction'] ?? 0) == _dayNo) return null;
    final pool = [
      for (final x in RegionRules.all)
        if (regionReached(x.region)) ...x.gear,
    ];
    return pool[_dayNo % pool.length];
  }

  Future<EquipItem?> buyAuction() => _serial(() async {
        final lot = auctionLot;
        if (lot == null || player.gold < RegionRules.auctionGold) return null;
        final today = await _todayRecord();
        await _save(today.copyWith(
            spends: DailyRecord.addCounts(today.spends, {Wallet.gold: RegionRules.auctionGold})));
        final item = await _a3Gear(lot, rare: true);
        _act3 = _act3.copyWith(prog: {..._act3.prog, 'sel:auction': _dayNo});
        await _saveAct3();
        _notify();
        return item;
      });

  // ───────────── 던전 5층 + 심층 (3막 뒤)

  bool regionDungeonOpen(RegionContent r) =>
      act3Open && (r.choice.afterLamp ? _rh(r, 'event') : regionChoice(r) != null);

  int regionFloorBest(RegionContent r) => _act3.prog[_rk(r, 'floorBest')] ?? 0;
  int regionFloorNow(RegionContent r) => _act3.prog[_rk(r, 'floorNow')] ?? 1;
  int regionDeepBest(RegionContent r) => _act3.prog[_rk(r, 'deepBest')] ?? 0;

  /// 그 층 정보 (6층부터는 심층: 지역 몬스터 둘, 5층마다 보스)
  FloorInfo regionFloor(RegionContent r, int n) {
    if (n <= r.floors.length) return r.floors[n - 1];
    final boss = n % 5 == 0;
    final a = r.normals[n % r.normals.length], b = r.normals[(n + 1) % r.normals.length];
    return FloorInfo(n, '심층 $n층',
        boss ? [r.floors[2].foes.first] : [a, b], boss: boss);
  }

  List<A3Enc>? regionEnterFloor(RegionContent r) {
    if (!regionDungeonOpen(r) || hp <= 0 || _act3.energy < Act3Rules.energyFloor) return null;
    final n = regionFloorNow(r);
    final f = regionFloor(r, n);
    _act3 = _act3.copyWith(energy: _act3.energy - Act3Rules.energyFloor);
    unawaited(_saveAct3());
    final place = _dungeonPlace(r);
    final kind = f.lamp ? A3Kind.lamp : f.boss ? A3Kind.mid : A3Kind.floor;
    final first = A3Enc(kind: kind, foes: f.foes, place: place, background: r.dungeonBg);
    if (f.boss || _random.nextDouble() >= BaldrinRules.secondFight) return [first];
    return [
      first,
      A3Enc(
          kind: A3Kind.floor,
          foes: [r.normals[_random.nextInt(r.normals.length)]],
          place: place,
          background: r.dungeonBg),
    ];
  }

  String _dungeonPlace(RegionContent r) => Act3Rules.region(r.region)
      .places
      .firstWhere((p) => p.kind == SpotKind.dungeon)
      .id;

  Future<BranchResult> regionTakeBranch(RegionContent r, Branch b) => _serial(() async {
        final n = regionFloorNow(r);
        switch (b) {
          case Branch.fight:
            return BranchResult(
                fight: A3Enc(
                    kind: A3Kind.floor,
                    foes: [
                      r.normals[_random.nextInt(r.normals.length)],
                      r.normals[_random.nextInt(r.normals.length)],
                    ],
                    place: _dungeonPlace(r),
                    background: r.dungeonBg),
                text: '갈림길 안쪽에서 몬스터 무리가 몰려와요.');
          case Branch.chest:
            final trap = _chestIsTrap(n);
            _chestN = null;
            if (trap) {
              final lost = math.max(1, (maxHp * BaldrinRules.trapHp).round());
              _vitals = _vitals.copyWith(hp: math.max(1, hp - lost));
              await store.saveVitals(_vitals);
              _notify();
              return BranchResult(hpLost: lost, text: '상자를 여는 순간 함정이 튀어나왔어요!');
            }
            final gold = BaldrinRules.chestGoldMin +
                _random.nextInt(BaldrinRules.chestGoldMax - BaldrinRules.chestGoldMin + 1);
            final more = await _consumeSkill(JobSkill.lockpick) ? gold : 0;
            await _grant(gold + more, 0, const {});
            final items = <EquipItem>[
              if (_random.nextDouble() < BaldrinRules.chestGear) await _a3Normal(r),
              if (_random.nextDouble() < RegionRules.uniqChest) await _a3Unique(r.uniques),
            ];
            await _saveAct3();
            _notify();
            return BranchResult(gold: gold + more, items: items, text: '낡은 보물 상자를 열었어요.');
          case Branch.story:
            final today = await _todayRecord();
            await _save(today.copyWith(
                gains: DailyRecord.addCounts(today.gains, {'exp': BaldrinRules.storyExp})));
            _notify();
            return BranchResult(
                exp: BaldrinRules.storyExp,
                text: n <= r.floorStories.length
                    ? r.floorStories[n - 1]
                    : '심층의 벽에 오래된 등불 그림이 희미하게 남아 있어요.');
        }
      });

  /// 층을 끝냄. 5층 뒤엔 1층부터 (3막이 끝났으면 심층으로). 그 층에서 생긴 이야기 한 줄
  Future<String?> regionClearFloor(RegionContent r) => _serial(() async {
        final n = regionFloorNow(r);
        final lines = <String>[];
        final next = n == r.floors.length
            ? (act3Done ? RegionRules.deepStart : 1)
            : n > r.floors.length && n % 5 == 0
                ? 1
                : n + 1;
        _act3 = _act3.copyWith(prog: {
          ..._act3.prog,
          _rk(r, 'floorBest'): math.max(regionFloorBest(r), math.min(n, r.floors.length)),
          _rk(r, 'floorNow'): next,
          if (n > r.floors.length) _rk(r, 'deepBest'): math.max(regionDeepBest(r), n),
        });
        for (final q in r.quests) {
          if (q.kind == RQKind.floor && n >= q.target && n <= r.floors.length) _questStep(q, lines);
        }
        // 니아: 상회에 넘겼다면 금고 3층에서 구해 냄
        if (n == 3 && r.region == Region.selenia && regionChoice(r) == 'hand' &&
            !storyJoined(StoryAlly.nia)) {
          _joinStory(StoryAlly.nia);
          lines.add('금고 3층 감옥에서 니아를 구했어요. 니아: 「…또 빚졌네. 이번엔 갚을게.」 니아가 동료가 됐어요.');
        }
        await _count('act3Floor');
        await _count('a3floor:${r.prefix}');
        // 묶음 58: 심층 주간 순위 (그 주 지역이면 서버에)
        if (n > r.floors.length) unawaited(_submitDeep(r, n));
        await _saveAct3();
        _notify();
        return lines.isEmpty ? null : lines.join('\n');
      });

  /// 심층에서 나와 1층부터 (이번 심층 기록은 남음)
  Future<void> leaveDeep(RegionContent r) => _serial(() async {
        if (regionFloorNow(r) <= r.floors.length) return;
        _act3 = _act3.copyWith(prog: {..._act3.prog, _rk(r, 'floorNow'): 1});
        await _saveAct3();
        _notify();
      });

  // ───────────── 숨은 장소

  bool regionHiddenOpen(RegionContent r) => _rh(r, 'hidden');
  bool regionHiddenCleared(RegionContent r) => _rh(r, 'hiddenBoss');
  bool regionHasPet(RegionContent r) =>
      r.hidden.pet != null && _pets.pets.any((p) => p.species == r.hidden.pet);

  A3Enc regionHiddenFight(RegionContent r) => A3Enc(
      kind: A3Kind.den,
      foes: [r.hidden.boss],
      place: r.hidden.place,
      energy: 10,
      background: Act3Rules.place(r.hidden.place)?.background);

  // ───────────── 지역 무기 (대장간 보스 장비 탭)

  bool regionWeaponCraftable(RegionContent r) {
    final i = EquipmentRules.info(r.weapon);
    return _rh(r, 'lamp') &&
        player.gold >= RegionRules.weaponGold &&
        player.manaStones >= i.manaStones &&
        i.recipe.entries.every((e) => player.materialCount(e.key) >= e.value);
  }

  Future<EquipItem?> craftRegionWeapon(RegionContent r) => _serial(() async {
        if (!regionWeaponCraftable(r)) return null;
        final i = EquipmentRules.info(r.weapon);
        final today = await _todayRecord();
        await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {
            Wallet.gold: RegionRules.weaponGold,
            Wallet.manaStone: i.manaStones,
            for (final e in i.recipe.entries) e.key.name: e.value,
          }),
        ));
        final item = await _a3Gear(r.weapon, rare: true, element: r.weaponElement);
        _act3 = _act3.flag(_rk(r, 'weapon'));
        await _saveAct3();
        await _npcUse(Npc.dorgun);
        _notify();
        return item;
      });

  /// 대장간에 보일 지역 무기 (등불을 켠 지역)
  List<RegionContent> get litRegionWeapons => [
        for (final r in RegionRules.all)
          if (_rh(r, 'lamp')) r,
      ];

  // ───────────── 묶음 58: 등불 켠 지역 재료가 현실 지도에 (그날 가끔, 지역마다 하나)

  /// 오늘 현실 지도에 나온 지역 재료 자리
  List<HarvestSpot> _regionMatSpots() {
    if (!act3Open) return const [];
    final day = DailyRecord.dayKeyOf(_clock());
    final from = _nearDay == day ? _nearAnchor : _lastFix?.point;
    if (from == null) return const [];
    return [
      for (final r in RegionRules.all)
        if (regionLit(r.region) && (_act3.prog['a3mat:${r.prefix}'] ?? 0) != _dayNo)
          if (math.Random('a3mat-${r.prefix}-$day'.hashCode) case final rng
              when rng.nextDouble() < RegionRules.mapMatChance)
            () {
              final d = RegionRules.mapMatMinM +
                  rng.nextDouble() * (RegionRules.mapMatMaxM - RegionRules.mapMatMinM);
              final b = rng.nextDouble() * 2 * math.pi;
              return HarvestSpot(
                id: 'a3mat-${r.prefix}-$day',
                kind: HarvestKind.relic,
                point: GeoPoint(from.lat + d * math.cos(b) / 111320,
                    from.lng + d * math.sin(b) / (111320 * math.cos(from.lat * math.pi / 180))),
              );
            }(),
    ];
  }

  bool _isRegionMat(HarvestSpot s) => s.id.startsWith('a3mat-');

  /// 그 자리의 지역 (지도 이름표 · 시트)
  RegionContent? regionOfSpot(HarvestSpot s) =>
      _isRegionMat(s) ? RegionRules.byPlace('${s.id.split('-')[1]}_') : null;

  /// 지역 재료를 줍는다: 그 지역 재료 1~2 + 금화 조금 (그날 한 번)
  Future<Map<MaterialId, int>?> _openRegionMat(HarvestSpot s) async {
    final r = regionOfSpot(s);
    if (r == null || (_act3.prog['a3mat:${r.prefix}'] ?? 0) == _dayNo) return null;
    final n = 1 + (_random.nextDouble() < 0.35 ? 1 : 0);
    final mats = {r.mapMat: n};
    final gold = 30 + _random.nextInt(41);
    await _grant(gold, 0, mats);
    _act3 = _act3.copyWith(prog: {..._act3.prog, 'a3mat:${r.prefix}': _dayNo});
    await _saveAct3();
    await _count('a3gather:${r.prefix}');
    _lastTreasureGold = gold;
    _notify();
    return mats;
  }

  // ───────────── 3막 끝

  Future<void> finishAct3Story() => _serial(() async {
        if (act3Done || !act3EndPending) return;
        _act3 = _act3.flag('act3End');
        final t = await _todayRecord();
        await _save(t.copyWith(
            counters: DailyRecord.addCounts(
                t.counters, {TitleRules.skyCounter(RegionRules.fiveLampsTitle): 1})));
        await _saveAct3();
        // 묶음 59: 4막이 열림
        if (!_act4.opened) {
          _act4 = _act4.copyWith(opened: true, chapter: 1, chapterSteps: _totalSteps);
          await _saveAct4();
        }
        _notify();
      });

  /// 이름 있는 장비 모음 (지역별)
  List<({String name, List<EquipBase> items, Map<EquipBase, String> stories, Map<EquipBase, String> effects})>
      get uniqueBook => [
            (
              name: Act3Rules.region(Region.baldrin).name,
              items: BaldrinRules.uniques,
              stories: BaldrinRules.stories,
              effects: BaldrinRules.uniqueEffects,
            ),
            for (final r in RegionRules.all)
              if (regionReached(r.region))
                (
                  name: Act3Rules.region(r.region).name,
                  items: r.uniques,
                  stories: r.uniqueStories,
                  effects: r.uniqueEffects,
                ),
          ];

  // ───────────── 싸움이 끝난 뒤 (지역 2~5)

  /// 이긴 뒤 지역 일: 진행 · 퀘스트 · 등불 · 숨은 보스. (모집권, 이번에 처음 등불)
  Future<(int, bool)> _regionAfterWin(RegionContent r, A3Enc e, List<String> lines) async {
    var tickets = 0;
    var lampNow = false;
    switch (e.kind) {
      case A3Kind.field:
        if (e.place == r.mains.first.place && !_rh(r, 'first')) {
          _act3 = _act3.flag(_rk(r, 'first'));
          lines.add('일지 · 「${r.mains.first.title}」을 끝냈어요');
        }
        for (final q in r.quests) {
          if (q.kind == RQKind.hunt && q.place == e.place) _questStep(q, lines);
        }
      case A3Kind.event:
        if (!_rh(r, 'event')) {
          _act3 = _act3.flag(_rk(r, 'event'));
          lines.addAll(r.eventLines);
        }
      case A3Kind.mid:
        for (final q in r.quests) {
          if (q.kind == RQKind.boss) _questStep(q, lines);
        }
      case A3Kind.lamp:
        final first = !_rh(r, 'lamp');
        final pieces = first ? RegionRules.pieceFirst : RegionRules.pieceAgain;
        await _grant(0, 0, {r.weaponMat: pieces},
            over: BagOver.mail, title: Materials.info(r.weaponMat).name);
        lines.add('${Materials.info(r.weaponMat).name} $pieces개를 얻었어요');
        if (!_rh(r, 'dungeon')) {
          _act3 = _act3.flag(_rk(r, 'dungeon'));
          tickets += BaldrinRules.dungeonTicket;
        }
        if (first) {
          _act3 = _act3.flag(_rk(r, 'lamp'));
          tickets += Act3Rules.ticketLamp;
          lampNow = true;
          final t = await _todayRecord();
          await _save(t.copyWith(
              counters: DailyRecord.addCounts(t.counters, {TitleRules.skyCounter(r.lampTitle): 1})));
        }
      case A3Kind.den:
        if (!_rh(r, 'hiddenBoss')) {
          _act3 = _act3.flag(_rk(r, 'hiddenBoss'));
          final t = await _todayRecord();
          await _save(t.copyWith(
              counters:
                  DailyRecord.addCounts(t.counters, {TitleRules.skyCounter(r.hidden.title): 1})));
          lines.add('칭호 「${TitleRules.info(r.hidden.title).name}」을 얻었어요');
        }
      case A3Kind.floor || A3Kind.wall || A3Kind.nest:
        break;
    }
    return (tickets, lampNow);
  }
}
