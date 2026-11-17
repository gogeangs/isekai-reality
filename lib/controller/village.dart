part of '../app_controller.dart';

/// 마을 개편 (묶음 35): 마을 탭 소개 · 막별 마을 · 마을 사람 · 펫 쉼터 · 지침
extension VillageOps on AppController {
  // ───────────── 막 (1막 이별 전 · 2막 이별부터 · 3 결말 뒤)

  int get villageAct => _act2.kingDone
      ? 3
      : _pets.farewellDone
          ? 2
          : 1;

  /// 펫 쉼터: Lv.11 첫 펫과 함께 열림
  bool get shelterOpen => _pets.farewellDone;

  // ───────────── 마을 탭 처음 소개 · 한마디

  /// 마을 탭 처음 소개 3줄을 보여 줄 때 (한 번만, 다른 안내가 없을 때)
  bool get villageIntroPending =>
      !_village.contains('intro') &&
      !inTutorial &&
      !guideTourActive &&
      pendingFeatureIntro == null &&
      !skillIntroPending;

  /// 소개 줄 (이별 뒤면 첫 펫이 말하고 3번째 줄이 바뀜)
  List<String> get villageIntroLines =>
      VillageRules.intro(departed: farewellDone ? firstSpiritName : null);

  Future<void> markVillageIntro() => _markVillage([
        'intro',
        // 이별 뒤 소개를 봤으면 이별 뒤 한마디는 따로 띄우지 않는다
        if (farewellDone) 'farewell',
      ]);

  /// 들어올 때 정령 배지 대신 한 번 하는 한마디 (없으면 null)
  /// 결말 뒤 탑 불꽃 → 이별 뒤 첫 마을 → 처음 넓어진 마을 순서
  String? get villageMoment {
    if (!_village.contains('intro')) return null;
    // 묶음 44 #225: 열린 뒤 처음 마을에 오면 「○○이 다 지어졌어!」
    final built = builtPending;
    if (built.isNotEmpty) {
      return VillageRules.builtLine(VillageRules.facilityName(built.first));
    }
    if (villageAct == 3 && !_village.contains('lit')) return VillageRules.towerLit;
    if (farewellDone && !_village.contains('farewell')) {
      return VillageRules.afterFarewell(firstSpiritName);
    }
    if (villageWide && !_village.contains('wide')) return VillageRules.wideLine;
    return null;
  }

  // ───────────── 묶음 44 #225: 공사 중 건물 · 완공 연출

  /// 그 시설이 열렸는지 (시설 이름: inn · shop · smithy · board · alchemy · guild · shelter)
  bool facilityOpen(String f) => switch (f) {
        'inn' || 'shop' => true,
        'smithy' => featureOpen(Feature.smithy),
        'board' => featureOpen(Feature.board),
        'alchemy' => featureOpen(Feature.alchemy),
        'guild' => jobsOpen,
        'shelter' => shelterOpen,
        'training' => trainingOpen,
        'garden' => gardenOpen,
        // 묶음 51: 주점은 만남 장면 뒤 · 거래소는 그다음 마을 방문
        'tavern' => tavernOpen,
        'market' => marketOpen,
        _ => false,
      };

  /// 안 열린 건물의 공사 단계 (1~3, 공사 그림이 없거나 열렸으면 null)
  int? buildStage(String f) {
    final at = VillageRules.buildLevels[f];
    if (at == null || facilityOpen(f)) return null;
    return VillageRules.buildStage(player.level.level, at);
  }

  /// 열린 뒤 아직 완공 연출을 안 본 건물
  List<String> get builtPending => !_village.contains('intro')
      ? const []
      : [
          for (final f in VillageRules.buildLevels.keys)
            if (facilityOpen(f) && !_village.contains('built:$f')) f,
          // 묶음 51 #229: 거래소 완공 (공사 그림 한 장 → 완공 그림)
          if (marketOpen && !_village.contains('built:market')) 'market',
        ];

  /// 완공 연출을 봤다 (건물마다 한 번)
  Future<void> markBuilt(List<String> fs) =>
      _markVillage([for (final f in fs) 'built:$f']);

  /// 예전 기록: 이미 열린 건물은 완공 그림 그대로 (연출 없음)
  Future<void> _migrateBuilt44() async {
    if (_village.contains('v44')) return;
    await _markVillage([
      'v44',
      for (final f in VillageRules.buildLevels.keys)
        if (facilityOpen(f)) 'built:$f',
    ]);
  }

  /// 묶음 43 #228: 예전 기록 Lv.13 이상은 훈련장을 완공 그림 그대로 (연출 없음, 카드는 한 번)
  Future<void> _migrateBuilt43() async {
    if (_village.contains('v43')) return;
    await _markVillage(['v43', if (trainingOpen) 'built:training']);
  }

  /// 결말 뒤 탑 불꽃이 켜지는 연출을 아직 안 봤는지
  bool get towerLightPending => villageAct == 3 && !_village.contains('lit');

  Future<void> markVillageMoment() async {
    final m = villageMoment;
    if (m == null) return;
    // 완공 한마디는 [markBuilt] 가 따로 남긴다
    if (builtPending.isNotEmpty) return;
    await _markVillage([
      if (m == VillageRules.towerLit) 'lit',
      if (m == VillageRules.wideLine) 'wide',
      if (m != VillageRules.towerLit && m != VillageRules.wideLine) 'farewell',
    ]);
  }

  /// 마을 그림을 좌우로 끌어서 둘러볼 만큼 시설이 많은지 (예시 모드는 미리 보기로 늘 넓게)
  bool get villageWide => villagePreviewWide;

  // ───────────── 마을 사람

  /// 이번에 들어갈 때 마을 사람 한마디 (처음이면 첫 줄). 부를 때마다 한 번 들어간 것으로 센다.
  /// 묶음 38 #213: 처음 만날 때 첫 줄 → [situation](상황 안내)이 있으면 그것 →
  /// 그 밖엔 「그 막의 평소 대사」와 [guide](기본 안내)를 번갈아
  String takeNpcLine(Npc n, {String? guide, String? situation}) {
    final met = _village.contains('met:${n.name}');
    final visits = _npcVisits[n.name] ?? 0;
    // 묶음 42 #226: 시설에 들르면 친해지기 점수 (하루 한 번)
    unawaited(_npcVisit(n));
    if (met && situation != null) return situation;
    // 묶음 53 #243: 은빛 털을 루미에게 보이면 바람의 굴이 열림 (한 번)
    if (met && n == Npc.lumi && hasSilverFur && !denOpen) {
      unawaited(showFurToLumi());
      return BaldrinRules.lumiFur;
    }
    // 묶음 51 #229: 거래소가 완공된 날 미나 말풍선 (한 번)
    if (met && n == Npc.mina) {
      final b = _takeMinaBarkan();
      if (b != null) return b;
    }
    // 묶음 49 #235: 루미·포포·세라가 영웅 펫을 처음 볼 때 한마디 (한 번)
    if (met) {
      final r = takeHeroReaction(n);
      if (r != null) return r;
    }
    // 묶음 42 #226: 처음 만날 때 첫 줄 → 상황 안내 → 부탁 알림 → 번갈아
    if (met && requestOffer(n) != null) return NpcRules.askLine;
    // 묶음 45 #231·#232: 특별한 부탁 · 작은 부탁 (게시판 쪽지를 여러 번 끝냈으면 그 말풍선)
    if (met && relicOffer(n) != null) return NpcRules.askLine;
    if (met && smallOffer(n) != null) {
      return _npc.smallBoard.contains(n.name)
          ? NpcSmallRules.boardAsk[n] ?? NpcRules.askLine
          : NpcRules.askLine;
    }
    final String line;
    // 단계가 오르면 그 사람 새 대사 2줄이 그 막의 평소 대사에 섞인다
    final acts = [
      ...VillageRules.linesFor(n, villageAct),
      ...npcStageLines(n),
      // 묶음 53: 3막 큰 고르기 · 등불 · 바람의 굴 뒤 새 대사
      ...act3NpcLines(n),
    ];
    if (met && guide != null) {
      line = visits.isOdd ? guide : acts[(visits ~/ 2) % acts.length];
    } else if (met) {
      line = acts[visits % acts.length];
    } else {
      line = VillageRules.lineFor(n, act: villageAct, met: met, visits: visits);
    }
    if (!met) {
      unawaited(_markVillage(['met:${n.name}']));
    } else {
      _npcVisits[n.name] = visits + 1;
      unawaited(_saveVillage());
    }
    return line;
  }

  // ───────────── 펫 쉼터 · 지침

  /// 「새로 열렸어요」 쉼터 카드 (한 번만, 예전 Lv.11 이상 계정도)
  bool get shelterIntroPending =>
      shelterOpen &&
      !_village.contains('shelterCard') &&
      !inTutorial &&
      pendingFeatureIntro == null &&
      !skillIntroPending &&
      !farewellPending;

  Future<void> markShelterIntro() => _markVillage(['shelterCard']);

  /// 묶음 43 #228: 「새로 열렸어요」 훈련장 카드 (한 번만, 예전 Lv.13 이상 계정도)
  bool get trainingIntroPending =>
      trainingOpen &&
      !_village.contains('trainingCard') &&
      !inTutorial &&
      pendingFeatureIntro == null &&
      !skillIntroPending &&
      !farewellPending &&
      !shelterIntroPending;

  Future<void> markTrainingIntro() => _markVillage(['trainingCard']);

  /// 지친 펫의 남은 시간 (지치지 않았으면 null)
  Duration? petTiredLeft(String uid) {
    final t = _pets.tired[uid];
    if (t == null) return null;
    final left = t.difference(_clock());
    return left.isNegative || left == Duration.zero ? null : left;
  }

  /// 지금 지친 펫들
  List<Pet> get tiredPets => [
        for (final p in _pets.pets)
          if (petTiredLeft(p.uid) != null) p,
      ];

  /// 쉼터에서 쉬게 했는지
  bool petInShelter(String uid) => _village.contains('rest:$uid');

  /// 지친 펫을 쉼터에 둔다: 지금부터 15분 뒤 풀린다 (남은 시간이 더 짧으면 그대로).
  /// 쉬는 동안에도 동행·던전은 그대로라 데려오기는 따로 없다.
  Future<bool> restInShelter(String uid) => _serial(() async {
        final t = _pets.tired[uid];
        if (t == null || !_clock().isBefore(t)) return false;
        final end = _clock().add(PetRules.shelterRest);
        await _savePets(_pets.copyWith(tired: {
          ..._pets.tired,
          uid: end.isBefore(t) ? end : t,
        }));
        await _markVillage(['rest:$uid']);
        await _npcUse(Npc.lumi);
        return true;
      });

  /// 다시 지치면 쉼터 표시를 지운다
  void _clearShelterRest(String uid) {
    if (_village.remove('rest:$uid')) unawaited(_saveVillage());
  }

  // ───────────── 저장

  Future<void> _markVillage(List<String> keys) async {
    final add = {...keys.where((k) => !_village.contains(k))};
    if (add.isEmpty) return;
    _village = {..._village, ...add};
    await _saveVillage();
    _notify();
  }

  Future<void> _saveVillage() => store.saveJson(AppController._villageKey, {
        'seen': _village.toList(),
        'visits': _npcVisits,
      });
}
