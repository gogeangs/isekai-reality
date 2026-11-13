part of '../app_controller.dart';

/// 보상형 광고 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension AdsOps on AppController {

  bool get adsReady => watchAd != null;

  Future<bool> _watchAd(String placement) async {
    final w = watchAd;
    if (w == null) return false;
    try {
      return await w(placement);
    } catch (_) {
      return false;
    }
  }

  /// 원정 시간 절반 (남은 시간의 절반). 튜토리얼 원정에는 없다
  bool canHalveExpedition(Expedition ex) =>
      adsReady &&
      !ex.finished &&
      !AppController.isTutorialSpawn(ex.spawnId) &&
      !ex.adUsed.contains('half') &&
      ex.returnAt.isAfter(_clock());

  Future<bool> adHalveExpedition(Expedition ex) async {
    if (!canHalveExpedition(ex) || !await _watchAd('expedition_half')) {
      return false;
    }
    return _serial(() async {
    final now = _clock();
    final cur = _latestExpedition(ex); // 묶음 23 #172: 사이에 도착했을 수 있다
    final left = cur.returnAt.difference(now);
    final done = cur.shortened(left ~/ 2, now, ad: 'half');
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
    await store.saveVitals(_vitals);
    final who = ex.petName ?? _profile.spiritName;
    unawaited(notifier?.schedule(_notifyIdFor(ex.petUid), done.returnAt,
        '${josa(who, '이/가')} 돌아왔어요', '원정 결과를 확인해 보세요!'));
    await refreshVitals();
    return true;
  });
  }
}
