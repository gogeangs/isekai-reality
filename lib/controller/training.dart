part of '../app_controller.dart';

/// 하루 훈련 결과
class DailyTrainingResult {
  const DailyTrainingResult({required this.cleared, required this.got});

  /// 넘긴 판 (0~3)
  final int cleared;

  /// 받은 것 글 ('금화 70' 등)
  final List<String> got;
}

/// 시련 결과
class TrialResult {
  const TrialResult({
    required this.floors,
    required this.best,
    required this.newBest,
    required this.marks,
    required this.got,
    this.title = false,
  });

  /// 이번에 넘긴 판
  final int floors;

  /// 이번 주 최고
  final int best;
  final bool newBest;

  /// 이번에 처음 넘긴 보상 판 (5 · 10 · 15)
  final List<int> marks;
  final List<String> got;

  /// 처음 15판을 넘겨 칭호를 받았는지
  final bool title;
}

/// 마을 새 건물 「훈련장」 (묶음 43 #228): 연습 · 하루 훈련 · 펫 훈련 · 시련.
/// 경험치는 주지 않는다. 훈련 전투는 HP가 가득 찬 채 시작하고, 끝나도 지금 HP·장비 내구도는 그대로
/// (시련에서 마신 물약만 쓴다)
extension TrainingOps on AppController {
  TrainingState get training => _training;

  /// Lv.13에 열림
  bool get trainingOpen => player.level.level >= TrainingRules.openLevel;

  String get _trainingWeek =>
      DailyRecord.dayKeyOf(TownRules.weekStart(_clock()));

  bool get dailyTrainingDone => _training.dailyDay == _today;
  bool get trialDoneToday => _training.trialDay == _today;
  bool get petTrainedToday => _training.petDay == _today;

  /// 오늘 하루 훈련을 아직 안 했는지 (마을 이름표 · 상태 탭 작은 점)
  bool get trainingDailyPending =>
      trainingOpen && !dailyTrainingDone && !inTutorial && !guideTourActive;

  /// 이번 주 시련 최고 판 · 받은 보상 판
  int get trialBestThisWeek =>
      _training.trialWeek == _trainingWeek ? _training.trialBest : 0;
  List<int> get trialMarksThisWeek =>
      _training.trialWeek == _trainingWeek ? _training.trialMarks : const [];

  /// 지금까지 가장 많이 넘긴 판
  int get trialEver => _training.trialEver;

  // ───────────── 전투 만들기

  Battle _trainingBattle(List<Foe> floors, {bool potions = false}) {
    final p = player;
    return _withJob(Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: floors,
      rng: _random,
      // 훈련은 HP가 가득 찬 채 시작 (지금 HP는 그대로 둔다)
      startHp: maxHp,
      skillChargeTicks: _skillTicks(p),
      gear: gear,
      power: combatPower() * jobPower,
      petSkill: companionPet?.info.skill,
      petAdult: companionPet?.adult ?? false,
      petResonant: companionPet != null && petResonant(companionPet!),
      potions: potions ? battlePotions : const [],
      autoHp: potions ? _alc.autoHp : 0,
      autoCure: potions ? _alc.autoCure : false,
      resist: activeResists,
      skillElement: companionPet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
      telegraphs: true,
      heroSkills: true,
    ));
  }

  // ───────────── ① 연습 (언제든)

  /// 허수아비 연습: 쓰러지지 않고 때리지 않는다. HP·내구도·MP·기력·보상 모두 그대로
  Battle? startPractice(DummyKind kind, {Element? element}) {
    if (!trainingOpen) return null;
    final b = _trainingBattle(
        [TrainingRules.practiceFoe(kind, player.level.level, element: element)]);
    b.practice = true;
    return b;
  }

  /// 연습을 마침: 가렌 부탁 셈(강타 · 방어 태세 · 스킬)과 친해지기만
  Future<void> finishPractice(Battle b) async {
    if (b.bashes > 0) await _npcTally(NpcTally.practiceBash);
    if (b.stances > 0) await _npcTally(NpcTally.practiceStance);
    if (b.skillsUsed > 0) await _npcTally(NpcTally.practiceSkill);
    await _npcUse(Npc.garen);
  }

  // ───────────── ② 하루 훈련 (하루 1번 · 3판)

  /// 하루 훈련을 시작한다 (시작하면 오늘 몫을 쓴다)
  Future<Battle?> startDailyTraining() => _serial(() async {
        if (!trainingOpen || dailyTrainingDone) return null;
        await _saveTraining(_training.copyWith(dailyDay: _today));
        return _trainingBattle(TrainingRules.dailyFoes(player.level.level));
      });

  /// 하루 훈련이 끝났을 때: 넘긴 판까지 금화 · 전투 숙련도 + 세 판 다 넘기면 가끔 재료
  Future<DailyTrainingResult> finishDailyTraining(Battle b) =>
      _serial(() async {
        final n = b.purified.length.clamp(0, 3);
        final gifts = <String, int>{};
        if (n > 0) {
          final gold = TrainingRules.dailyGold.take(n).fold<int>(0, (t, g) => t + g);
          gifts[Wallet.gold] = (gold * garenGold).round();
          await gainMastery(Mastery.combat, TrainingRules.dailyMastery * n);
        }
        if (n >= 3 && _random.nextDouble() < TrainingRules.dailyMatChance) {
          final m = TrainingRules.dailyMats[_random.nextInt(TrainingRules.dailyMats.length)];
          gifts[m.name] = 1 + _random.nextInt(2);
        }
        final got = gifts.isEmpty ? <String>[] : await _applyGifts(gifts);
        await _npcTally(NpcTally.dailyTraining);
        await _npcUse(Npc.garen);
        _notify();
        return DailyTrainingResult(cleared: n, got: got);
      });

  // ───────────── ③ 펫 훈련 (하루 1번 · 8시간)

  /// 훈련 중인 펫인지
  bool petInTraining(String? uid) =>
      uid != null && _training.petUid == uid && petTrainingLeft(uid) != null;

  /// 훈련이 끝날 때까지 남은 시간 (훈련 중이 아니면 null)
  Duration? petTrainingLeft(String uid) {
    if (_training.petUid != uid) return null;
    final end = _training.petEnd;
    if (end == null) return null;
    final left = end.difference(_clock());
    return left > Duration.zero ? left : null;
  }

  /// 지금 훈련 중인 펫
  Pet? get trainingPet {
    final uid = _training.petUid;
    return uid == null ? null : _pets.byUid(uid);
  }

  /// 맡길 수 없는 이유 (맡길 수 있으면 null)
  String? petTrainingBlock(Pet p) {
    if (isAway(p.uid)) return '원정 중';
    if (petTiredLeft(p.uid) != null) return '지쳐서 쉬는 중';
    return null;
  }

  /// 펫 하나를 맡긴다 (8시간 뒤 펫 경험치)
  Future<bool> startPetTraining(String uid) => _serial(() async {
        if (!trainingOpen || petTrainedToday || _training.petUid != null) {
          return false;
        }
        final p = _pets.byUid(uid);
        if (p == null || petTrainingBlock(p) != null) return false;
        final end = _clock().add(TrainingRules.petTime);
        await _saveTraining(
            _training.copyWith(petUid: uid, petEnd: end, petDay: _today));
        unawaited(notifier?.schedule(NotifyId.petTraining, end, '펫 훈련',
            '${josa(p.name, '이/가')} 훈련을 마쳤어요'));
        await _npcUse(Npc.garen);
        _notify();
        return true;
      });

  /// 끝난 펫 훈련을 마무리한다 (펫 경험치 · 위쪽 띠 한 번)
  Future<void> _settlePetTraining() async {
    final uid = _training.petUid;
    final end = _training.petEnd;
    if (uid == null || end == null || _clock().isBefore(end)) return;
    final p = _pets.byUid(uid);
    await _saveTraining(_training.copyWith(clearPet: true));
    if (p == null) return;
    await _givePetExp(uid, TrainingRules.petExp);
    await _npcTally(NpcTally.petTraining);
    _petTrainedNotice = p.name;
    _notify();
  }

  /// 방금 훈련을 마친 펫 이름 (한 번만)
  String? takePetTrainedNotice() {
    final n = _petTrainedNotice;
    _petTrainedNotice = null;
    return n;
  }

  // ───────────── ④ 시련 (매주 월요일 새로 · 하루 1번)

  /// 시련을 시작한다 (시작하면 오늘 몫을 쓴다). 물약을 쓸 수 있다
  Future<Battle?> startTrial() => _serial(() async {
        if (!trainingOpen || trialDoneToday) return null;
        var t = _training;
        if (t.trialWeek != _trainingWeek) {
          t = t.copyWith(trialWeek: _trainingWeek, trialBest: 0, trialMarks: const []);
        }
        await _saveTraining(t.copyWith(trialDay: _today));
        return _trainingBattle(TrainingRules.trialFoes(player.level.level),
            potions: true);
      });

  /// 시련이 끝났을 때: 이번 주 최고 · 처음 넘긴 5·10·15판 보상 · 처음 15판 칭호
  Future<TrialResult> finishTrial(Battle b) => _serial(() async {
        await _consumeBattlePotions(b);
        final n = b.purified.length;
        var t = _training;
        if (t.trialWeek != _trainingWeek) {
          t = t.copyWith(trialWeek: _trainingWeek, trialBest: 0, trialMarks: const []);
        }
        final marks = [
          for (final m in TrainingRules.trialMarks)
            if (n >= m && !t.trialMarks.contains(m)) m,
        ];
        final gifts = <String, int>{};
        for (final m in marks) {
          TrainingRules.trialReward(m).forEach((k, v) => gifts[k] = (gifts[k] ?? 0) + v);
        }
        final title = n >= TrainingRules.trialTitleAt && t.trialEver < TrainingRules.trialTitleAt;
        final newBest = n > t.trialBest;
        await _saveTraining(t.copyWith(
          trialBest: math.max(t.trialBest, n),
          trialMarks: [...t.trialMarks, ...marks],
          trialEver: math.max(t.trialEver, n),
        ));
        final got = gifts.isEmpty ? <String>[] : await _applyGifts(gifts);
        if (title) {
          final today = await _todayRecord();
          await _save(today.copyWith(
              counters: DailyRecord.addCounts(today.counters, {TitleRules.trialCounter: 1})));
        }
        if (n >= 10) await _npcTally(NpcTally.trial10);
        await _npcUse(Npc.garen);
        _notify();
        return TrialResult(
          floors: n,
          best: math.max(t.trialBest, n),
          newBest: newBest && n > 0,
          marks: marks,
          got: got,
          title: title,
        );
      });

  // ───────────── 저장

  Future<void> _saveTraining(TrainingState s) async {
    _training = s;
    await store.saveJson(AppController._trainingKey, s.toJson());
    _notify();
  }
}
