part of '../app_controller.dart';

/// 건물 레벨업 (묶음 54): 결말(본체) 뒤 마을 건물 10채를 ★1 → ★3 으로 고친다.
/// 금화 + 재료를 그 시설 마을 사람에게 가져다 주면 「고치는 중」(★2 1시간 · ★3 4시간) →
/// 다 고치면 그 단계 효과가 바로 켜지고, 마을에 들어올 때 레벨업 연출 한 번.
extension BuildingOps on AppController {
  /// 결말(본체를 쓰러뜨림) 뒤에 열림 (Lv.21 전이어도)
  bool get buildingsOpen => _act2Ready && _act2.kingDone && !inTutorial;

  /// 그 건물 단계 (다 고친 것만, 고치는 시간이 지났으면 올라간 단계)
  int buildingStar(Building b) {
    final s = _buildings.starOf(b.name);
    final at = _buildings.fixing[b.name];
    return at != null && !_clock().isBefore(at) ? math.min(3, s + 1) : s;
  }

  /// 시설 이름으로 (마을 그림 · 이름표). 레벨업이 없는 시설은 ★1
  int facilityStar(String name) =>
      switch (BuildingRules.parse(name)) { final b? => buildingStar(b), null => 1 };

  /// 고치는 중이면 남은 시간
  Duration? buildingFixLeft(Building b) {
    final at = _buildings.fixing[b.name];
    if (at == null) return null;
    final left = at.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  bool buildingFixing(Building b) => buildingFixLeft(b) != null;

  /// 이 건물을 지금 고칠 수 있는 판인지 (열렸고, ★3 전이고, 고치는 중이 아님)
  bool buildingUpgradeOpen(Building b) =>
      buildingsOpen &&
      facilityOpen(b.name) &&
      buildingStar(b) < BuildingRules.maxStar &&
      !buildingFixing(b);

  /// 다음 단계에 드는 것 (더 고칠 게 없으면 null)
  BuildingNeed? buildingNeed(Building b) {
    final s = buildingStar(b);
    return s >= BuildingRules.maxStar ? null : BuildingRules.info(b).needFor(s + 1);
  }

  /// 모은 정도: 채운 칸 수 / 모든 칸 수 (금화 한 칸 + 재료마다 한 칸)
  (int, int) buildingProgress(Building b) {
    final n = buildingNeed(b);
    if (n == null) return (0, 0);
    var have = player.gold >= n.gold ? 1 : 0;
    for (final e in n.mats.entries) {
      if (player.materialCount(e.key) >= e.value) have++;
    }
    return (have, n.mats.length + 1);
  }

  bool canUpgradeBuilding(Building b) {
    if (!buildingUpgradeOpen(b)) return false;
    final (have, all) = buildingProgress(b);
    return all > 0 && have == all;
  }

  /// 가져다 준다: 금화 · 재료를 쓰고 고치기 시작 (그동안에도 시설은 그대로)
  Future<bool> deliverBuilding(Building b) => _serial(() async {
        await _settleBuildings();
        if (!canUpgradeBuilding(b)) return false;
        final n = buildingNeed(b)!;
        final today = await _todayRecord();
        await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {
            Wallet.gold: n.gold,
            for (final e in n.mats.entries) e.key.name: e.value,
          }),
        ));
        final to = buildingStar(b) + 1;
        final at = _clock().add(BuildingRules.fixTime(to));
        await _saveBuildings(_buildings.copyWith(
            fixing: {..._buildings.fixing, b.name: at}));
        final info = BuildingRules.info(b);
        unawaited(notifier?.schedule(NotifyId.building, at, '${info.name} ★$to',
            '${info.name}을 다 고쳤어요! 마을에서 확인해 보세요.'));
        await _npcUse(info.npc);
        _notify();
        return true;
      });

  /// 고치는 시간이 지난 건물을 다 고친 것으로 남긴다 (마을 연출 기다림에 넣음)
  Future<void> _settleBuildings() async {
    final now = _clock();
    final done = [
      for (final e in _buildings.fixing.entries)
        if (!now.isBefore(e.value)) e.key,
    ];
    if (done.isEmpty) return;
    await _saveBuildings(_buildings.copyWith(
      stars: {
        ..._buildings.stars,
        for (final n in done) n: math.min(3, _buildings.starOf(n) + 1),
      },
      fixing: {..._buildings.fixing}..removeWhere((k, _) => done.contains(k)),
      reveal: [..._buildings.reveal, for (final n in done) if (!_buildings.reveal.contains(n)) n],
    ));
  }

  /// 마을에서 레벨업 연출을 볼 건물 (다 고친 뒤 처음 한 번)
  Set<String> get starPending => {
        ..._buildings.reveal,
        for (final e in _buildings.fixing.entries)
          if (!_clock().isBefore(e.value)) e.key,
      };

  Future<void> markStarSeen(Iterable<String> names) => _serial(() async {
        await _settleBuildings();
        await _saveBuildings(_buildings.copyWith(reveal: [
          for (final n in _buildings.reveal)
            if (!names.contains(n)) n,
        ]));
      });

  // ───────────── 효과 (숨은 값)

  bool _star(Building b, int s) => buildingsOpen && buildingStar(b) >= s;

  /// 여관 ★3 (묶음 81 #373): 가득 찬 뒤 일어나면 잠시 HP · 기력 최대가 조금 늘어요 (숨김)
  bool get innBoostOn {
    final u = _buildings.innBoostUntil;
    return u != null && _clock().isBefore(u);
  }

  Future<void> _innRested() async {
    if (!_star(Building.inn, 3)) return;
    await _saveBuildings(
        _buildings.copyWith(innBoostUntil: _clock().add(InnRules.star3For)));
  }

  /// 게시판: 의뢰 칸 · 하루 의뢰 수 +1 (★2)
  int get boardExtraSlots => _star(Building.board, 2) ? 1 : 0;
  int get errandsPerDay => BoardRules.errandsPerDay + boardExtraSlots;

  /// 조합 ★2: 「곧 열릴 것 같은 직업」 힌트 더 자세히
  bool get guildDetailHint => _star(Building.guild, 2);

  /// 연금술 공방 ★3: 가마솥 하나 더
  int get cauldronCount => _alc.cauldrons + (_star(Building.alchemy, 3) ? 1 : 0);

  /// 펫 쉼터 ★3: 알 두 개를 함께 품기
  int get eggSlots => _star(Building.shelter, 3) ? 2 : 1;
  bool get canIncubateMore =>
      _pets.eggs.where((e) => e.incubatedAt != null).length < eggSlots;

  /// 훈련장 ★3: 시련 보상 판
  List<int> get trialMarks => [
        ...TrainingRules.trialMarks,
        if (_star(Building.training, 3)) BuildingRules.trialExtraMark,
      ];

  /// 주점: 버섯 수프는 ★2 부터
  List<MealInfo> get mealMenu => [
        for (final m in TavernRules.meals)
          if (m.id != Meal.mushroomSoup || _star(Building.tavern, 2) || todayMeal == m.id) m,
      ];

  Future<void> _saveBuildings(BuildingState s) async {
    _buildings = s;
    await store.saveJson(AppController._buildingsKey, s.toJson());
    _notify();
  }
}
