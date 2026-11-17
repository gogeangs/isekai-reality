part of '../app_controller.dart';

/// 3막 싸움 종류 (묶음 53)
enum A3Kind {
  /// 지역 지도 필드 사냥 (여정 기력 5)
  field,

  /// 지하 요새 층 싸움 · 갈림길 싸움 (층에 들어갈 때 기력을 씀)
  floor,

  /// 3층 중간 보스 · 5층 등불 보스 · 바람의 굴 숨은 보스
  mid,
  lamp,
  den,

  /// 메인 ③ 성벽길 · 한나 퀘스트 하피 둥지
  wall,
  nest,
}

/// 3막 싸움 하나
class A3Enc {
  const A3Enc({required this.kind, required this.foes, this.place, this.energy = 0, this.background});

  final A3Kind kind;
  final List<MonsterId> foes;
  final String? place;
  final int energy;
  final String? background;
}

/// 지하 요새 갈림길 결과
class BranchResult {
  const BranchResult({this.fight, this.gold = 0, this.items = const [], this.hpLost = 0, this.text = '', this.exp = 0});

  /// 「싸움」이면 이어서 할 싸움
  final A3Enc? fight;
  final int gold;
  final List<EquipItem> items;
  final int hpLost;
  final String text;
  final int exp;
}

/// 3막 지역 1 「발드린 관문」 (묶음 53 #243): 야영지 · 주민 · 메인 ②~⑤ · 서브 4 · 지하 요새 ·
/// 큰 고르기 · 바람의 굴 · 등불 · 지역 무기 · 아르카 마을 새 대사
extension Act3RegionOps on AppController {
  // ───────────── 메인 흐름

  /// 지금 메인 단계 (0 ① 첫 싸움 · 1 ② 볼크 · 2 ③ 성벽길 · 3 ④ 요새 · 4 ⑤ 등불 · 5 끝)
  int get mainStep {
    final s = _act3;
    if (!s.firstFight) return 0;
    if (!s.has('volk')) return 1;
    if (s.choice == null) return 2;
    if (s.floorBest < 4) return 3;
    if (!s.has('lamp')) return 4;
    return 5;
  }

  /// 일지 메인 (지금까지 연 것 + 지금 할 것)
  List<({String title, String text, bool done, String? place})> get journalMain => [
        for (final (i, m) in BaldrinRules.mains.indexed)
          if (i <= mainStep && i < BaldrinRules.mains.length)
            (title: m.title, text: m.text, done: i < mainStep, place: m.place),
      ];

  /// 일지 서브 (받은 것 · 끝낸 것)
  List<({SideQuestInfo q, int prog, bool ready, bool done})> get journalSides => [
        for (final q in BaldrinRules.sides)
          if ((_act3.quests[q.id.name] ?? 0) > 0)
            (
              q: q,
              prog: math.min(q.target, _act3.prog[q.id.name] ?? 0),
              ready: sideReady(q.id),
              done: _act3.quests[q.id.name] == 2,
            ),
      ];

  bool get volkTalkPending => _act3.firstFight && !_act3.has('volk');

  Future<void> markVolkTalk() async {
    if (_act3.has('volk')) return;
    _act3 = _act3.flag('volk');
    await _saveAct3();
    _notify();
  }

  /// ③ 성벽길 안쪽 살피기 (볼크 이야기 뒤, 편지 전)
  bool get wallPending => _act3.has('volk') && _act3.choice == null;

  /// 편지를 찾았고 아직 고르지 않음
  bool get choicePending => _act3.has('wallFought') && _act3.choice == null;

  A3Enc get wallFight => const A3Enc(
      kind: A3Kind.wall, foes: BaldrinRules.wallFoes, place: 'baldrin_wallroad', energy: 5,
      background: 'assets/images/bg_baldrin_wallroad.webp');

  /// 큰 고르기 「테오의 편지」 (한 번 고르면 바꿀 수 없음)
  Future<EquipItem?> chooseLetter({required bool marta}) => _serial(() async {
        if (!choicePending) return null;
        EquipItem? spear;
        if (marta) {
          _act3 = _act3.copyWith(choice: 'marta', lunch: _act3.lunch + BaldrinRules.lunchCount);
        } else {
          _act3 = _act3.copyWith(choice: 'garen');
          spear = await _a3Gear(EquipBase.uniqTeoSpear, rare: true, element: Element.light);
          await _npcUse(Npc.garen);
        }
        await _saveAct3();
        _notify();
        return spear;
      });

  int get lunchCount => _act3.lunch;

  /// 마르타의 도시락: 여정 기력 +40
  Future<bool> eatLunch() => _serial(() async {
        if (_act3.lunch <= 0 || _act3.energy >= Act3Rules.energyMax) return false;
        _act3 = _act3.copyWith(
          lunch: _act3.lunch - 1,
          energy: math.min(Act3Rules.energyMax, _act3.energy + BaldrinRules.lunchEnergy),
        );
        await _saveAct3();
        _notify();
        return true;
      });

  // ───────────── 야영지 (천막 여관 · 피피의 노점 · 의뢰판 · 주민)

  bool residentMet(Resident r) => _act3.has('met:${r.name}');

  /// 주민 한마디 (처음엔 첫 줄 → 그 뒤 번갈아 · 퀘스트를 맡길 수 있으면 「!」)
  String residentLine(Resident r) {
    final info = BaldrinRules.resident(r);
    if (!residentMet(r)) {
      _act3 = _act3.flag('met:${r.name}');
      unawaited(_saveAct3());
      return info.first;
    }
    final n = (_a3Talk[r.name] ?? 0) + 1;
    _a3Talk[r.name] = n;
    // 큰 고르기 · 등불 뒤 바뀐 한마디
    if (r == Resident.volk && _act3.has('lamp') && n.isOdd) {
      return '등불이 다시 켜졌다. …문지기들아, 보고 있느냐.';
    }
    if (r == Resident.hanna && _act3.choice == 'marta' && n.isOdd) {
      return '마르타가 도시락을 싸 줬다고요? 그 손맛, 저도 알아요. 아껴 먹어요.';
    }
    return info.lines[n % info.lines.length];
  }

  /// 이 주민이 맡길 수 있는 서브 퀘스트 (아직 안 받음)
  SideQuestInfo? residentOffer(Resident r) {
    if (!act3Open || !_act3.firstFight) return null;
    for (final q in BaldrinRules.sides) {
      if (q.giver == r && (_act3.quests[q.id.name] ?? 0) == 0) return q;
    }
    return null;
  }

  /// 가렌 동료 퀘스트 (의뢰판에 「가렌의 부탁」으로)
  SideQuestInfo? get garenOffer {
    if (!act3Open || !_act3.has('volk')) return null;
    return (_act3.quests[SideQuest.roster.name] ?? 0) == 0
        ? BaldrinRules.side(SideQuest.roster)
        : null;
  }

  int sideState(SideQuest q) => _act3.quests[q.name] ?? 0;
  int sideProg(SideQuest q) => _act3.prog[q.name] ?? 0;

  bool sideReady(SideQuest q) {
    if (sideState(q) != 1) return false;
    if (q == SideQuest.stall) return stallMats != null;
    return sideProg(q) >= BaldrinRules.side(q).target;
  }

  Future<void> acceptSide(SideQuest q) async {
    if (sideState(q) != 0) return;
    _act3 = _act3.copyWith(quests: {..._act3.quests, q.name: 1});
    await _saveAct3();
    _notify();
  }

  /// 진행 한 칸 (받은 퀘스트만)
  void _sideStep(SideQuest q, List<String> lines, String line) {
    if (sideState(q) != 1) return;
    final t = BaldrinRules.side(q).target;
    final now = sideProg(q);
    if (now >= t) return;
    _act3 = _act3.copyWith(prog: {..._act3.prog, q.name: now + 1});
    lines.add('$line (${now + 1}/$t)');
  }

  /// 피피에게 건넬 재료 3종 (많이 가진 것부터, 종류마다 2개). 모자라면 null
  Map<MaterialId, int>? get stallMats {
    final have = [
      for (final m in NpcRules.anyMats)
        if (player.materialCount(m) >= BaldrinRules.stallEach) m,
    ]..sort((a, b) => player.materialCount(b).compareTo(player.materialCount(a)));
    if (have.length < BaldrinRules.side(SideQuest.stall).target) return null;
    return {for (final m in have.take(3)) m: BaldrinRules.stallEach};
  }

  /// 퀘스트 보고: 모집권 1 + 금화 (가렌은 스킬 ④가 열림)
  Future<bool> reportSide(SideQuest q) => _serial(() async {
        if (!sideReady(q)) return false;
        if (q == SideQuest.stall) {
          final take = stallMats!;
          final today = await _todayRecord();
          await _save(today.copyWith(
              spends: DailyRecord.addCounts(
                  today.spends, {for (final e in take.entries) e.key.name: e.value})));
          _act3 = _act3.flag('stall');
        }
        await _grant(BaldrinRules.sideGold, 0, const {});
        _act3 = _act3.copyWith(
          quests: {..._act3.quests, q.name: 2},
          tickets: _act3.tickets + BaldrinRules.sideTickets,
        );
        await _saveAct3();
        if (q == SideQuest.roster) await _npcUse(Npc.garen);
        _notify();
        return true;
      });

  /// 가렌 스킬 ④는 「신병 다섯의 명부」를 끝내야 열림
  bool get garenRosterDone => sideState(SideQuest.roster) == 2;

  /// 하피 둥지 (한나 퀘스트를 받았고 아직 못 구함)
  bool get nestPending =>
      sideState(SideQuest.child) == 1 && sideProg(SideQuest.child) < 1;

  A3Enc get nestFight => const A3Enc(
      kind: A3Kind.nest, foes: BaldrinRules.nestFoes, place: 'baldrin_wolfhill', energy: 5,
      background: 'assets/images/bg_baldrin_wolfhill.webp');

  /// 천막 여관: 쉬면 HP · MP 가득, 하루 한 번 여정 기력 +30
  bool get innEnergyToday => _act3.innDay != _a3Day;

  Future<int> restAtTent() async {
    await levelUpHeal();
    if (!innEnergyToday) return 0;
    final before = _act3.energy;
    _act3 = _act3.copyWith(
      innDay: _a3Day,
      energy: math.min(Act3Rules.energyMax, before + BaldrinRules.innEnergy),
    );
    await _saveAct3();
    await _npcUse(Npc.marta);
    _notify();
    return _act3.energy - before;
  }

  /// 피피의 노점 (퀘스트를 끝내면 물건이 늘어남). 사는 건 아르카 잡화상과 같은 값 · 하루 개수
  List<ShopItem> get stallItems => [
        ...BaldrinRules.stall,
        if (_act3.has('stall')) ...BaldrinRules.stallMore,
      ];

  // ───────────── 지하 요새 5층

  bool get dungeonOpen => act3Open && _act3.choice != null;
  int get floorNow => _act3.floorNow;
  int get floorBest => _act3.floorBest;

  /// 층에 들어간다 (여정 기력 10). 싸울 차례 목록 (보스 층은 하나)
  List<A3Enc>? enterFloor() {
    if (!dungeonOpen || hp <= 0 || _act3.energy < Act3Rules.energyFloor) return null;
    final f = BaldrinRules.floors[_act3.floorNow - 1];
    _act3 = _act3.copyWith(energy: _act3.energy - Act3Rules.energyFloor);
    unawaited(_saveAct3());
    final kind = f.lamp ? A3Kind.lamp : f.boss ? A3Kind.mid : A3Kind.floor;
    final first = A3Enc(kind: kind, foes: f.foes, place: 'baldrin_fort',
        background: BaldrinRules.dungeonBg);
    if (f.boss || _random.nextDouble() >= BaldrinRules.secondFight) return [first];
    final normals = const [MonsterId.goblinRaider, MonsterId.skeletonGuard, MonsterId.ogre];
    return [
      first,
      A3Enc(
          kind: A3Kind.floor,
          foes: [normals[_random.nextInt(normals.length)]],
          place: 'baldrin_fort',
          background: BaldrinRules.dungeonBg),
    ];
  }

  /// 갈림길 하나를 고른다 (층 싸움을 다 이긴 뒤)
  Future<BranchResult> takeBranch(Branch b) => _serial(() async {
        final n = _act3.floorNow;
        switch (b) {
          case Branch.fight:
            final normals = const [MonsterId.goblinRaider, MonsterId.skeletonGuard, MonsterId.ogre];
            return BranchResult(
                fight: A3Enc(
                    kind: A3Kind.floor,
                    foes: [normals[_random.nextInt(normals.length)], normals[_random.nextInt(2)]],
                    place: 'baldrin_fort',
                    background: BaldrinRules.dungeonBg),
                text: '갈림길 안쪽에서 몬스터 무리가 몰려와요.');
          case Branch.chest:
            if (_random.nextDouble() >= BaldrinRules.chestChance) {
              final lost = math.max(1, (maxHp * BaldrinRules.trapHp).round());
              _vitals = _vitals.copyWith(hp: math.max(1, hp - lost));
              await store.saveVitals(_vitals);
              _notify();
              return BranchResult(hpLost: lost, text: '상자를 여는 순간 화살이 튀어나왔어요! 함정이었어요.');
            }
            final gold = BaldrinRules.chestGoldMin +
                _random.nextInt(BaldrinRules.chestGoldMax - BaldrinRules.chestGoldMin + 1);
            await _grant(gold, 0, const {});
            final items = <EquipItem>[
              if (_random.nextDouble() < BaldrinRules.chestGear) await _a3Normal(),
              if (_random.nextDouble() < BaldrinRules.uniqChest)
                await _a3Unique(BaldrinRules.uniques),
            ];
            await _saveAct3();
            _notify();
            return BranchResult(gold: gold, items: items, text: '낡은 보물 상자를 열었어요.');
          case Branch.story:
            final today = await _todayRecord();
            await _save(today.copyWith(
                gains: DailyRecord.addCounts(today.gains, {'exp': BaldrinRules.storyExp})));
            _notify();
            return BranchResult(
                exp: BaldrinRules.storyExp, text: BaldrinRules.floorStories[n - 1]);
        }
      });

  /// 층을 끝냄 (다음엔 그다음 층부터, 5층을 끝내면 다시 1층부터)
  Future<void> clearFloor() async {
    final n = _act3.floorNow;
    _act3 = _act3.copyWith(
      floorBest: math.max(_act3.floorBest, n),
      floorNow: n >= BaldrinRules.floors.length ? 1 : n + 1,
    );
    await _count('act3Floor');
    await _saveAct3();
    _notify();
  }

  // ───────────── 바람의 굴 (숨은 장소)

  bool get denOpen => _act3.has('den');
  bool get hasSilverFur => _act3.has('fur');
  bool get denCleared => _act3.has('denBoss');

  /// 루미에게 은빛 털을 보였을 때 (펫 쉼터에 들어갈 때) 굴이 열림
  Future<bool> showFurToLumi() async {
    if (!_act3.has('fur') || _act3.has('den')) return false;
    _act3 = _act3.flag('den');
    await _saveAct3();
    _notify();
    return true;
  }

  bool get hasWindPet => _pets.pets.any((p) => p.species == PetSpecies.wolf);

  A3Enc get denFight => const A3Enc(
      kind: A3Kind.den, foes: [MonsterId.ashWolfAlpha], place: 'baldrin_windden', energy: 10,
      background: BaldrinRules.denBg);

  /// 등불을 켰는지 (현실 지도 몬스터 · 지역 무기 · 다음 길)
  bool get baldrinLit => _act3.has('lamp');

  /// 이름 있는 장비 모음 (얻은 적 있는지)
  bool uniqueFound(EquipBase b) => _act3.found.contains(b.name);

  // ───────────── 지역 무기 「관문의 빛 창」 (대장간 보스 장비 탭)

  bool get spearCraftable {
    final i = EquipmentRules.info(EquipBase.baldrinSpear);
    return baldrinLit &&
        player.gold >= BaldrinRules.spearGold &&
        player.manaStones >= i.manaStones &&
        i.recipe.entries.every((e) => player.materialCount(e.key) >= e.value);
  }

  Future<EquipItem?> craftSpear() => _serial(() async {
        if (!spearCraftable) return null;
        final i = EquipmentRules.info(EquipBase.baldrinSpear);
        final today = await _todayRecord();
        await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {
            Wallet.gold: BaldrinRules.spearGold,
            Wallet.manaStone: i.manaStones,
            for (final e in i.recipe.entries) e.key.name: e.value,
          }),
        ));
        final item = await _a3Gear(EquipBase.baldrinSpear,
            rare: true, element: BaldrinRules.spearElement);
        _act3 = _act3.flag('spear');
        await _saveAct3();
        await _npcUse(Npc.dorgun);
        _notify();
        return item;
      });

  // ───────────── 아르카 마을 사람 새 대사 (큰 고르기 · 등불 · 바람의 굴 뒤)

  List<String> act3NpcLines(Npc n) {
    final s = _act3;
    return [
      if (n == Npc.marta && s.choice == 'marta') ...BaldrinRules.martaAfterMarta,
      if (n == Npc.marta && s.choice == 'garen') ...BaldrinRules.martaAfterGaren,
      if (n == Npc.garen && s.choice == 'garen') ...BaldrinRules.garenAfterGaren,
      if (n == Npc.garen && s.choice == 'marta') ...BaldrinRules.garenAfterMarta,
      if (s.has('lamp') && (n == Npc.lian || n == Npc.mina)) ...BaldrinRules.afterLamp,
      if (s.has('lamp') && n == Npc.hart) BaldrinRules.hartAfterLamp,
      if (s.has('denBoss') && n == Npc.lumi) BaldrinRules.lumiAfterDen,
    ];
  }

  /// 현실 지도에 섞일 3막 몬스터 (등불을 켠 지역의 일반 몬스터)
  List<MonsterId> get lampMonsters => baldrinLit ? BaldrinRules.normals : const [];
}
