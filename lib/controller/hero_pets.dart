part of '../app_controller.dart';

/// 영웅 펫 6종 (묶음 49 #235): 동행 중 걸을 때 함께하는 효과 · 마을 사람 한마디.
/// 효과 크기는 숨은 값, 화면엔 문장만 ([PetSpeciesInfo.walk]).
extension HeroPetOps on AppController {
  /// 동행 중인 영웅 펫 (없으면 null)
  Pet? get heroCompanion {
    if (!farewellDone) return null;
    final p = companionPet;
    return p != null && p.hero ? p : null;
  }

  bool _heroWith(PetSpecies s) => heroCompanion?.species == s;

  /// 가진 영웅 펫이 있는지
  bool get hasHeroPet => _pets.pets.any((p) => p.hero);

  // ───────────── 그날 기준 자리 (그날 처음 위치)

  GeoPoint? get _heroAnchor {
    final p = _pets;
    final day = DailyRecord.dayKeyOf(_clock());
    if (p.heroDay == day && p.heroLat != null && p.heroLng != null) {
      return GeoPoint(p.heroLat!, p.heroLng!);
    }
    final here = _lastFix?.point;
    if (heroCompanion == null || here == null) return null;
    unawaited(_saveHeroDay(here));
    return here;
  }

  Future<void> _saveHeroDay(GeoPoint here) async {
    final day = DailyRecord.dayKeyOf(_clock());
    final p = _pets;
    if (p.heroDay == day && p.heroLat != null) return;
    await _savePets(p.copyWith(
      heroDay: day,
      heroLat: here.lat,
      heroLng: here.lng,
      heroWalk: p.heroDay == day ? p.heroWalk : (player.today?.steps ?? 0),
    ));
  }

  // ───────────── 녹턴 · 엠버: 나에게만 보이는 몬스터

  /// 녹턴(밤 몬스터) · 엠버(잿빛 몬스터): 그날 기준 자리 둘레
  List<FieldSpawn> _heroSpawns(
      List<FieldSpawn> Function(GeoPoint p, String key, int count, {bool night})
          around) {
    final h = heroCompanion;
    if (h == null) return const [];
    final anchor = _heroAnchor;
    if (anchor == null) return const [];
    final day = DailyRecord.dayKeyOf(_clock());
    switch (h.species) {
      case PetSpecies.panther:
        if (!FieldMonsterRules.isNight(_clock())) return const [];
        return around(anchor, 'nocturne$day', PetRules.pantherNightSpawns,
            night: true);
      case PetSpecies.phoenix:
        return [
          for (final f in around(anchor, 'ember$day', PetRules.phoenixAshSpawns))
            FieldSpawn(
                id: f.id,
                monster: MonsterId.ashSlime,
                point: f.point,
                modifiers: f.modifiers),
        ];
      default:
        return const [];
    }
  }

  // ───────────── 무: 하늘에서 떨어진 재료

  /// 그날 이만큼 걸으면 기준 자리 둘레 150~400m에 상자 하나 (하루 한 번)
  List<HarvestSpot> _skySpots() {
    if (!_heroWith(PetSpecies.whale)) return const [];
    final day = DailyRecord.dayKeyOf(_clock());
    if (_pets.skyDay == day) return const [];
    if ((player.today?.steps ?? 0) < PetRules.whaleSkySteps) return const [];
    final from = _heroAnchor;
    if (from == null) return const [];
    final rng = math.Random(day.hashCode);
    final d = 150 + rng.nextDouble() * 250;
    final b = rng.nextDouble() * 2 * math.pi;
    final at = GeoPoint(
        from.lat + d * math.cos(b) / 111320,
        from.lng +
            d * math.sin(b) / (111320 * math.cos(from.lat * math.pi / 180)));
    return [HarvestSpot(id: 'sky-chest-$day', kind: HarvestKind.relic, point: at)];
  }

  bool _isSkyChest(HarvestSpot s) => s.id.startsWith('sky-chest-');

  /// 하늘 상자를 연다: 금화 조금 + 재료 2 (하루 한 번)
  Future<Map<MaterialId, int>?> _openSky(HarvestSpot s) async {
    final day = DailyRecord.dayKeyOf(_clock());
    if (s.id != 'sky-chest-$day' || _pets.skyDay == day) return null;
    final gold = PetRules.whaleSkyGoldMin +
        _random.nextInt(PetRules.whaleSkyGoldMax - PetRules.whaleSkyGoldMin + 1);
    const pool = [
      MaterialId.windJelly,
      MaterialId.waterJelly,
      MaterialId.butterflyDust,
      MaterialId.essence,
      MaterialId.breezeBloom,
    ];
    final mats = <MaterialId, int>{};
    for (var i = 0; i < 2; i++) {
      final k = pool[_random.nextInt(pool.length)];
      mats[k] = (mats[k] ?? 0) + 1;
    }
    await _savePets(_pets.copyWith(skyDay: day));
    await _grant(gold, 0, mats);
    _lastTreasureGold = gold;
    _notify();
    return mats;
  }

  // ───────────── 모스: 채집 자리가 조금 빨리

  Duration get _spotRecharge => _heroWith(PetSpecies.turtle)
      ? HarvestRules.recharge * PetRules.turtleRecharge
      : HarvestRules.recharge;

  // ───────────── 바람: 원정 간 다른 펫이 조금 빨리

  double _wolfTravel(Pet? sent) =>
      sent != null && _heroWith(PetSpecies.wolf) && heroCompanion?.uid != sent.uid
          ? PetRules.wolfOthersTravel
          : 1;

  // ───────────── 엠버: 던전에서 한 번 되살아남

  Battle _withPhoenix(Battle b) {
    if (_heroWith(PetSpecies.phoenix)) b.revives = 1;
    return b;
  }

  // ───────────── 여명: 이른 아침 걸음으로 HP·기력

  Future<void> _heroWalk() async {
    final today = player.today;
    if (today == null) return;
    final p = _pets;
    final day = today.dayKey;
    final last = p.heroDay == day ? p.heroWalk : 0;
    if (!_heroWith(PetSpecies.stag)) {
      if (p.heroDay == day && last != today.steps) {
        await _savePets(p.copyWith(heroWalk: today.steps));
      }
      return;
    }
    if (today.steps <= last && p.heroDay == day) return;
    if (PetRules.isDawn(_clock())) {
      final k = today.steps ~/ 1000 - last ~/ 1000;
      if (k > 0) {
        _vitals = _vitals.copyWith(
          hp: math.min(maxHp, hp + (maxHp * PetRules.stagHp * k).round()),
          mp: math.min(mpMax, mp + PetRules.stagMp * k),
          lastMaxHp: maxHp,
        );
        await store.saveVitals(_vitals);
      }
    }
    await _savePets(p.copyWith(heroDay: day, heroWalk: today.steps));
  }

  // ───────────── 마을 사람 한마디 (처음 만날 때 한 번)

  /// 루미·포포·세라가 영웅 펫을 처음 볼 때 한마디 (없으면 null). 한 번 꺼내면 본 것으로
  String? takeHeroReaction(Npc n) {
    // 묶음 57 #244: 루미 · 리안이 전설 펫을 처음 볼 때 (영웅 한마디와 따로 한 번)
    final legend = takeLegendReaction(n);
    if (legend != null) return legend;
    if (!hasHeroPet || _pets.heroMet.contains(n.name)) return null;
    bool has(PetSpecies s) => _pets.pets.any((p) => p.species == s);
    final line = switch (n) {
      Npc.lumi => has(PetSpecies.wolf)
          ? '바, 바람?! 정말 바람이야? …너한테 와 줬구나. 잘 부탁해!'
          : '와아, 영웅 펫이잖아! 저쪽 세계에서도 보기 힘든 아이야!',
      Npc.popo => has(PetSpecies.turtle)
          ? '모스?! 우리 숲을 지키던 모스예요! 손님 곁에 있었다니!'
          : '와아! 그 아이, 저쪽 숲 냄새가 나요! 아주 귀한 아이예요!',
      Npc.sera => has(PetSpecies.panther)
          ? '녹턴… 근위대의 짐승이다. 너를 주인으로 골랐다면, 믿어도 된다.'
          : '…영웅의 짐승이군. 함부로 대하지 마라. 그만큼 너를 믿는 거다.',
      _ => null,
    };
    if (line == null) return null;
    unawaited(_savePets(_pets.copyWith(heroMet: [..._pets.heroMet, n.name])));
    return line;
  }

  /// 묶음 57 #244: 전설 펫을 처음 볼 때 루미 · 리안 한마디 (기획 확인 전 초안)
  String? takeLegendReaction(Npc n) {
    if (n != Npc.lumi && n != Npc.lian) return null;
    final legends = [for (final p in _pets.pets) if (p.legend) p];
    if (legends.isEmpty || _pets.legendTalk.contains(n.name)) return null;
    final p = legends.first;
    final line = n == Npc.lumi
        ? '…잠깐, 그 아이 ${p.info.name}이지? 할머니 옛이야기에만 나오던 전설 속 펫이야! ${p.name}, 반가워. 우리 바람이랑도 친하게 지내 줘!'
        : '${p.info.name}… 저쪽 세계 노래에 나오던 그 전설이 정말 있었구나. ${p.name}와 함께라면 다리 너머 어디든 갈 수 있겠어.';
    unawaited(_savePets(_pets.copyWith(legendTalk: [..._pets.legendTalk, n.name])));
    return line;
  }
}
