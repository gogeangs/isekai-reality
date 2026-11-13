part of '../app_controller.dart';

/// 마법 돋보기·감정 앨범 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension LensOps on AppController {

  LensState get lens => _lens;

  /// 도감 「종족」에 남은 종족
  Set<Race> get racesSeen => {
        for (final n in _lens.seen)
          if (LensRules.parse(n) case final r?) r,
      };

  /// 오늘 보상을 더 받을 수 있는 감정 횟수
  int get lensRewardsLeft {
    final day = DailyRecord.dayKeyOf(_clock());
    final used = _lens.day == day ? _lens.rewardedToday : 0;
    return math.max(0, LensRules.rewardedPerDay - used);
  }

  /// 오늘 무료 감정이 남았는지 (자정에 다시 채움)
  bool get lensFreeToday =>
      _lens.freeDay != DailyRecord.dayKeyOf(_clock());

  /// 지금 감정할 수 있는지 (무료 또는 가방 돋보기)
  bool get canAppraise => lensFreeToday || bagCount(ShopItem.raceLens) > 0;

  /// 감정을 끝낸다: 마법 돋보기 1개를 쓰고 보상을 준다. 돋보기가 없으면 null.
  /// 처음 본 종족은 도감에 남고 경험치 +20, 하루 3번까지 30% 재료·5% 레시피 쪽지.
  Future<AppraiseResult?> appraise(List<Race> races) =>
      _serial(() async {
    if (races.isEmpty || !canAppraise) return null;
    // 묶음 19 #154: 매일 첫 감정은 돋보기를 쓰지 않는다
    final free = lensFreeToday;
    final today = await _todayRecord();
    final firsts = <Race>[
      for (final r in {...races})
        if (!_lens.seen.contains(r.name)) r,
    ];
    final exp = firsts.length * LensRules.firstExp;
    final rewarded = lensRewardsLeft > 0;
    MaterialId? mat;
    var note = false;
    if (rewarded) {
      if (_random.nextDouble() < LensRules.materialChance) {
        mat = LensRules.info(races[_random.nextInt(races.length)]).material;
      }
      note = _random.nextDouble() < LensRules.noteChance;
    }
    await _save(today.copyWith(
      itemsUsed: free
          ? today.itemsUsed
          : [...today.itemsUsed, ShopItem.raceLens.name],
      gains: exp > 0
          ? DailyRecord.addCounts(today.gains, {Wallet.exp: exp})
          : today.gains,
    ));
    final day = today.dayKey;
    final now = _clock();
    final photo = AlbumPhoto(
      id: 'p${now.microsecondsSinceEpoch}',
      races: [for (final r in races) r.name],
      at: now,
      firsts: [for (final r in firsts) r.name],
    );
    _lens = _lens.copyWith(
      album: [..._lens.album, photo],
      seen: [..._lens.seen, for (final r in firsts) r.name],
      counts: {
        ..._lens.counts,
        for (final r in {...races})
          r.name: (_lens.counts[r.name] ?? 0) +
              races.where((x) => x == r).length,
      },
      day: day,
      freeDay: free ? day : null,
      rewardedToday:
          (_lens.day == day ? _lens.rewardedToday : 0) + (rewarded ? 1 : 0),
    );
    await store.saveJson(AppController._lensKey, _lens.toJson());
    if (mat != null) await _grant(0, 0, {mat: 1});
    if (note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    _notify();
    return AppraiseResult(
        races: races,
        firsts: firsts,
        exp: exp,
        material: mat,
        note: note,
        albumId: photo.id);
  });

  /// 감정 앨범 (11-11 #97)
  List<AlbumPhoto> get album => _lens.album;

  /// 앨범 사진에 찍은 사진 파일을 붙인다
  Future<void> attachAlbumFile(String id, String file) async {
    _lens = _lens.copyWith(album: [
      for (final p in _lens.album) p.id == id ? p.withFile(file) : p,
    ]);
    await store.saveJson(AppController._lensKey, _lens.toJson());
    _notify();
  }

  /// 앨범에서 지운다 (지운 사진의 파일 이름, 없으면 null). 감정한 종족 기록은 그대로.
  Future<String?> deleteAlbumPhoto(String id) async {
    String? file;
    for (final p in _lens.album) {
      if (p.id == id) file = p.file;
    }
    _lens = _lens.copyWith(album: [
      for (final p in _lens.album)
        if (p.id != id) p,
    ]);
    await store.saveJson(AppController._lensKey, _lens.toJson());
    _notify();
    return file;
  }
}
