part of '../app_controller.dart';

/// 작은 부탁을 끝낸 결과
class NpcSmallDone {
  const NpcSmallDone(
      {required this.thanks, required this.got, this.relicOffered = false});

  /// 고맙다는 한마디
  final String thanks;
  final List<String> got;

  /// 이번에 그 사람 전용 퀘스트(특별한 부탁)가 나왔는지
  final bool relicOffered;
}

/// 상태 탭 「마을 사람 부탁」 한 줄 (큰 부탁 · 작은 부탁 · 특별한 부탁)
class NpcAskLine {
  const NpcAskLine(this.npc, this.kind, this.progress,
      {this.stage = 0, this.stages = 0});

  final Npc npc;
  final AskKind kind;
  final List<NpcStepProgress> progress;

  /// 특별한 부탁의 지금 단계(0부터) · 모든 단계 수
  final int stage;
  final int stages;

  bool get ready => progress.isNotEmpty && progress.every((x) => x.done);
}

/// 묶음 45 #231·#232: 마을 사람 작은 부탁 · 게시판 쪽지 · 전용 아이템 퀘스트.
/// 큰 부탁(사연)·친해지기 규칙은 그대로, 작은 부탁은 친밀도 단계와 상관없이 그 건물이 열린 뒤
extension NpcSmallOps on AppController {
  // ───────────── 받을 때 · 셈

  /// 할 일 셈을 받을 때의 값으로 (받은 뒤부터 센다)
  ActiveRequest _startAsk(int index, List<NpcRequestStep> steps) => ActiveRequest(
        index: index,
        day: DailyRecord.dayKeyOf(_clock()),
        base: {
          for (final s in steps)
            if (s.kind == RequestStepKind.tally) s.key: _npc.tally[s.key] ?? 0,
        },
        steps: player.today?.steps ?? 0,
      );

  List<NpcStepProgress> _progressOf(
          List<NpcRequestStep> steps, ActiveRequest a) =>
      [for (final s in steps) NpcStepProgress(s, _stepHave(s, a))];

  /// 가져오는 재료를 가방에서 뺀다 (종류마다 많이 가진 것부터)
  Future<void> _handOver(List<NpcRequestStep> steps) async {
    final take = <MaterialId, int>{};
    for (final s in steps) {
      if (s.kind != RequestStepKind.deliver) continue;
      final mats = [...NpcRules.matsOf(s)]
        ..sort((x, y) => player.materialCount(y).compareTo(player.materialCount(x)));
      var left = s.need;
      for (final m in mats) {
        if (left <= 0) break;
        final have = player.materialCount(m) - (take[m] ?? 0);
        if (have <= 0) continue;
        final k = s.distinct ? 1 : math.min(have, left);
        take[m] = (take[m] ?? 0) + k;
        left -= k;
      }
    }
    if (take.isEmpty) return;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {for (final e in take.entries) e.key.name: e.value})));
  }

  /// 경험치 조금 (걷기가 중심이라 작게)
  Future<void> _npcExp(int exp) async {
    if (exp <= 0) return;
    final today = await _todayRecord();
    await _save(today.copyWith(gains: DailyRecord.addCounts(today.gains, {'exp': exp})));
  }

  // ───────────── 작은 부탁

  /// 건물이 열린 마을 사람 이름 (게시판 쪽지용)
  List<String> get _openNpcNames => [
        for (final n in Npc.values)
          if (_npcReady && !_requestsQuiet && npcHomeOpen(n)) n.name,
      ];

  /// 받을 수 있는 작은 부탁 (없으면 null)
  NpcSmall? smallOffer(Npc n) {
    if (_requestsQuiet || !npcHomeOpen(n)) return null;
    final i = _npc.smallOffer[n.name];
    return i == null ? null : NpcSmallRules.small(n, i);
  }

  /// 작은 부탁 말 (게시판 쪽지를 여러 번 끝내서 생겼으면 그 말풍선)
  String smallSay(Npc n) {
    final s = smallOffer(n) ?? smallActive(n);
    if (s == null) return '';
    if (_npc.smallBoard.contains(n.name)) {
      return '${NpcSmallRules.boardAsk[n] ?? ''} ${s.say}'.trim();
    }
    return s.say;
  }

  /// 받은 작은 부탁
  NpcSmall? smallActive(Npc n) {
    final a = _npc.small[n.name];
    return a == null ? null : NpcSmallRules.small(n, a.index);
  }

  List<NpcStepProgress> smallProgress(Npc n) {
    final a = _npc.small[n.name];
    final s = smallActive(n);
    return a == null || s == null ? const [] : _progressOf(s.steps, a);
  }

  bool smallReady(Npc n) {
    final p = smallProgress(n);
    return p.isNotEmpty && p.every((x) => x.done);
  }

  /// 상황에 따라 그 사람이 작은 부탁을 하나 낸다 (한 사람에 하나씩, 하루 제한 없음)
  Future<void> _smallTrigger(Npc n, {bool board = false}) async {
    if (!_npcReady || _requestsQuiet || !npcHomeOpen(n)) return;
    if (_npc.smallOffer.containsKey(n.name) || _npc.small.containsKey(n.name)) return;
    final pool = NpcSmallRules.smallsOf(n);
    if (pool.isEmpty) return;
    final last = _npc.smallLast[n.name];
    final choices = [
      for (var i = 0; i < pool.length; i++)
        if (i != last || pool.length == 1) i,
    ];
    final pick = choices[_random.nextInt(choices.length)];
    await _saveNpc(_npc.copyWith(
      smallOffer: {..._npc.smallOffer, n.name: pick},
      smallLast: {..._npc.smallLast, n.name: pick},
      smallBoard: board
          ? {..._npc.smallBoard, n.name}.toList()
          : [for (final x in _npc.smallBoard) if (x != n.name) x],
    ));
    _smallNotice = n;
  }

  /// 방금 생긴 작은 부탁 (위쪽 띠 한 번)
  Npc? takeSmallNotice() {
    final n = _smallNotice;
    _smallNotice = null;
    return _requestsQuiet ? null : n;
  }

  Future<bool> acceptSmall(Npc n) => _serial(() async {
        final s = smallOffer(n);
        final i = _npc.smallOffer[n.name];
        if (s == null || i == null) return false;
        await _saveNpc(_npc.copyWith(
          smallOffer: {..._npc.smallOffer}..remove(n.name),
          small: {..._npc.small, n.name: _startAsk(i, s.steps)},
        ));
        return true;
      });

  /// 작은 부탁을 끝냄: 친밀도 · 경험치 조금 · 고맙다는 한마디 (사연 없음). 가끔 전용 퀘스트
  Future<NpcSmallDone?> completeSmall(Npc n) => _serial(() async {
        final s = smallActive(n);
        if (s == null || !smallReady(n)) return null;
        await _handOver(s.steps);
        await _npcExp(NpcSmallRules.smallExp);
        var st = _npc.copyWith(
          small: {..._npc.small}..remove(n.name),
          smallDone: {..._npc.smallDone, n.name: (_npc.smallDone[n.name] ?? 0) + 1},
          smallBoard: [for (final x in _npc.smallBoard) if (x != n.name) x],
        );
        // 전용 퀘스트: 가끔 (안 나오면 다음엔 조금 더 잘 나옴). 사람마다 한 번
        var offered = false;
        final had = st.relics.contains(n.name) ||
            st.relicOffer.contains(n.name) ||
            st.relic.containsKey(n.name);
        if (!had) {
          final miss = st.relicMiss[n.name] ?? 0;
          if (_random.nextDouble() < NpcSmallRules.relicChanceAfter(miss)) {
            offered = true;
            st = st.copyWith(
              relicOffer: [...st.relicOffer, n.name],
              relicMiss: {...st.relicMiss}..remove(n.name),
            );
          } else {
            st = st.copyWith(relicMiss: {...st.relicMiss, n.name: miss + 1});
          }
        }
        await _saveNpc(st);
        await _addFavor(n, NpcSmallRules.smallFavor);
        return NpcSmallDone(
          thanks: s.thanks,
          got: ['경험치 ${NpcSmallRules.smallExp}'],
          relicOffered: offered,
        );
      });

  // ───────────── 게시판 「마을 사람 의뢰」

  /// 게시판 마을 사람 쪽지를 끝냄: 친밀도 · 경험치 · 5번마다 직접 작은 부탁
  Future<void> _boardNoteDone(ErrandTemplate t) async {
    final who = Npc.values.where((n) => n.name == t.npc).firstOrNull;
    if (who == null) return;
    await _npcExp(t.exp);
    final done = (_npc.boardDone[who.name] ?? 0) + 1;
    await _saveNpc(_npc.copyWith(boardDone: {..._npc.boardDone, who.name: done}));
    await _addFavor(who, NpcSmallRules.boardFavor);
    if (done % NpcSmallRules.boardAskEvery == 0) {
      await _smallTrigger(who, board: true);
    }
  }

  /// 길드 의뢰가 새로 붙는 시간 (하르트의 낡은 지도통이면 조금 빨리)
  Duration get _errandCooldown => hasRelic(Npc.hart)
      ? NpcSmallRules.mapcaseCooldown
      : BoardRules.errandCooldown;

  // ───────────── 전용 아이템 퀘스트 (특별한 부탁)

  NpcRelic? relicOffer(Npc n) =>
      !_requestsQuiet && npcHomeOpen(n) && _npc.relicOffer.contains(n.name)
          ? NpcSmallRules.relicOf(n)
          : null;

  NpcRelic? relicActive(Npc n) =>
      _npc.relic.containsKey(n.name) ? NpcSmallRules.relicOf(n) : null;

  /// 지금 단계 (0부터)
  int relicStage(Npc n) => _npc.relic[n.name]?.index ?? 0;

  List<NpcStepProgress> relicProgress(Npc n) {
    final a = _npc.relic[n.name];
    final r = relicActive(n);
    if (a == null || r == null || a.index >= r.stages.length) return const [];
    return _progressOf(r.stages[a.index].steps, a);
  }

  /// 마지막 단계까지 다 했는지 (「다 했어요」)
  bool relicReady(Npc n) {
    final r = relicActive(n);
    if (r == null || relicStage(n) != r.stages.length - 1) return false;
    final p = relicProgress(n);
    return p.isNotEmpty && p.every((x) => x.done);
  }

  Future<bool> acceptRelic(Npc n) => _serial(() async {
        final r = relicOffer(n);
        if (r == null) return false;
        await _saveNpc(_npc.copyWith(
          relicOffer: [for (final x in _npc.relicOffer) if (x != n.name) x],
          relic: {..._npc.relic, n.name: _startAsk(0, r.stages.first.steps)},
        ));
        await _advanceRelics();
        return true;
      });

  /// 단계를 다 하면 다음 단계로 (마지막 단계는 「다 했어요」로 끝냄). 단계마다 한마디
  Future<void> _advanceRelics() async {
    if (!_npcReady || _npc.relic.isEmpty) return;
    var st = _npc;
    var changed = false;
    for (final e in _npc.relic.entries) {
      final n = Npc.values.where((x) => x.name == e.key).firstOrNull;
      if (n == null) continue;
      final r = NpcSmallRules.relicOf(n);
      var a = e.value;
      while (a.index < r.stages.length - 1 &&
          _progressOf(r.stages[a.index].steps, a).every((x) => x.done)) {
        final next = a.index + 1;
        a = _startAsk(next, r.stages[next].steps);
        _relicStageNotice = (n, r.stages[next].line);
        changed = true;
      }
      st = st.copyWith(relic: {...st.relic, e.key: a});
    }
    if (changed) await _saveNpc(st);
  }

  /// 방금 다음 단계로 넘어간 전용 퀘스트 (마을 사람 · 한마디, 위쪽 띠 한 번)
  (Npc, String)? takeRelicStageNotice() {
    final x = _relicStageNotice;
    _relicStageNotice = null;
    return _requestsQuiet ? null : x;
  }

  /// 「다 했어요」: 전용 아이템(가방 「소중한 물건」) + 친밀도
  Future<NpcRelic?> completeRelic(Npc n) => _serial(() async {
        final r = relicActive(n);
        if (r == null || !relicReady(n)) return null;
        await _handOver(r.stages.last.steps);
        await _saveNpc(_npc.copyWith(
          relic: {..._npc.relic}..remove(n.name),
          relics: {..._npc.relics, n.name}.toList(),
        ));
        await _addFavor(n, NpcSmallRules.relicFavor);
        return r;
      });

  /// 그 사람 전용 아이템을 가졌는지 (가지고만 있으면 효과)
  bool hasRelic(Npc n) => _npc.relics.contains(n.name);

  /// 가방 「소중한 물건」 (받은 차례)
  List<NpcRelic> get ownedRelics => [
        for (final name in _npc.relics)
          if (Npc.values.where((x) => x.name == name).firstOrNull case final n?)
            NpcSmallRules.relicOf(n),
      ];

  /// 엘리엘의 별빛 플라스크: 물약을 마셔도 병이 남는지 (마실 때마다 굴림)
  bool get _bottleKept =>
      hasRelic(Npc.eliel) && _random.nextDouble() < NpcSmallRules.starFlask;

  /// 미나의 주판: 잡화상에 팔 때 금화 조금 더
  int _abacus(int gold) => hasRelic(Npc.mina) && gold > 0
      ? (gold * NpcSmallRules.abacusGold).round()
      : gold;

  /// 걸으면 듣는 전용 아이템 (마르타 HP · 도르군 내구도 · 가렌 전투 숙련도)
  Future<void> _relicWalk() async {
    if (!_npcReady) return;
    final today = player.today;
    if (today == null) return;
    final walkers = [Npc.marta, Npc.dorgun, Npc.garen].where(hasRelic).toList();
    final from = _npc.walkDay == today.dayKey ? _npc.walkSteps : 0;
    if (walkers.isEmpty) {
      if (_npc.walkDay != today.dayKey || from != today.steps) {
        await _saveNpc(_npc.copyWith(walkDay: today.dayKey, walkSteps: today.steps));
      }
      return;
    }
    final to = today.steps;
    if (to <= from && _npc.walkDay == today.dayKey) return;
    // 1,000보 · 2,000보 단위로 넘은 횟수
    int crossed(int unit) => to ~/ unit - from ~/ unit;
    if (hasRelic(Npc.marta)) {
      final k = crossed(1000);
      if (k > 0 && hp < maxHp) {
        _vitals = _vitals.copyWith(
            hp: math.min(maxHp, hp + (maxHp * NpcSmallRules.flaskHp * k).round()),
            lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      }
    }
    if (hasRelic(Npc.dorgun)) {
      final k = crossed(NpcSmallRules.anvilSteps);
      if (k > 0) {
        var a = _armory;
        for (final item in a.worn) {
          if (item.durability >= EquipmentRules.maxDurability) continue;
          a = a.replace(item.copyWith(
              durability: math.min(EquipmentRules.maxDurability, item.durability + k)));
        }
        if (!identical(a, _armory)) await _saveArmory(a);
      }
    }
    if (hasRelic(Npc.garen)) {
      final k = crossed(1000);
      if (k > 0) await gainMastery(Mastery.combat, NpcSmallRules.weightMastery * k);
    }
    await _saveNpc(_npc.copyWith(walkDay: today.dayKey, walkSteps: math.max(from, to)));
  }

  // ───────────── 보여 주기

  /// 마을 이름표 표시: 큰 부탁(금빛 「!」) 먼저, 그다음 특별한 부탁, 작은 부탁
  AskKind? npcAskKind(Npc n) {
    if (_requestsQuiet) return null;
    if (npcAttention(n)) return AskKind.big;
    if (relicOffer(n) != null || relicReady(n)) return AskKind.special;
    if (smallOffer(n) != null || smallReady(n)) return AskKind.small;
    return null;
  }

  /// 상태 탭 「마을 사람 부탁」: 받은 부탁 모두 (큰 · 특별한 · 작은)
  List<NpcAskLine> get activeAsks => [
        for (final n in Npc.values) ...[
          if (requestActive(n) != null)
            NpcAskLine(n, AskKind.big, requestProgress(n)),
          if (relicActive(n) case final r?)
            NpcAskLine(n, AskKind.special, relicProgress(n),
                stage: relicStage(n), stages: r.stages.length),
          if (smallActive(n) != null)
            NpcAskLine(n, AskKind.small, smallProgress(n)),
        ],
      ];
}
