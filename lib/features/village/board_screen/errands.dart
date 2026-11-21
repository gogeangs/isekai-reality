part of '../board_screen.dart';

/// 길드 의뢰 칸 (예전 「수시 의뢰」)
class _ErrandPanel extends StatelessWidget {
  const _ErrandPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final b = controller.board;
    return FoldingQuestPanel(
      done: b.doneToday >= controller.errandsPerDay,
      foldedText: '조합 의뢰 오늘 모두 완료 · ${b.doneToday}개',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardPlaque('조합 의뢰',
              note: '오늘 ${b.doneToday} / ${controller.errandsPerDay}'),
          const _BoardNote('수락하면 시작 · 끝내면 2시간 뒤 새 의뢰 · 자정에 모두 바뀌어요'),
          const SizedBox(height: 4),
          // 묶음 78 #309: 다 한 의뢰(받기)가 맨 위
          NoteGrid(children: [
            for (final i in _errandOrder(controller, [for (var i = 0; i < b.slots.length; i++) i]))
              _ErrandNote(controller: controller, slot: i),
          ]),
        ],
      ),
    );
  }
}

/// 길드 의뢰 남은 시간 (자정까지)
String _untilMidnight(DateTime now) {
  final mid = DateTime(now.year, now.month, now.day + 1);
  final left = mid.difference(now);
  return left.inHours > 0
      ? '${left.inHours}시간 ${left.inMinutes % 60}분'
      : '${left.inMinutes % 60 + 1}분';
}

class _ErrandNote extends StatefulWidget {
  const _ErrandNote({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  State<_ErrandNote> createState() => _ErrandNoteState();
}

class _ErrandNoteState extends State<_ErrandNote> {
  /// 방금 보상을 받은 쪽지 (인장 → 사라짐)
  (String, String)? _claimed;

  Future<void> _claim(ErrandTemplate t) async {
    final c = widget.controller;
    final ok = await c.claimErrand(widget.slot);
    if (!mounted || !ok) return;
    setState(() => _claimed = (
          'errand|${widget.slot}|${t.id}|${c.now.millisecondsSinceEpoch}',
          t.title
        ));
    showTopNotice(context, '의뢰 완료! ${t.rewardLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final slot = widget.slot;
    final b = c.board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId, level: c.player.level.level);
    final claimed = _claimed;
    if (claimed != null && !_vanished.contains(claimed.$1)) {
      return VanishingNote(
        id: claimed.$1,
        child: SmallNote(title: claimed.$2, seed: slot + 7, done: true),
      );
    }
    if (t == null) {
      final ready = s.readyAt;
      final String text;
      if (b.doneToday >= c.errandsPerDay) {
        text = '오늘 조합 의뢰는 다 끝냈어요';
      } else if (ready != null && c.now.isBefore(ready)) {
        final left = ready.difference(c.now);
        text = '새 의뢰가 ${left.inHours > 0 ? '${left.inHours}시간 ' : ''}'
            '${left.inMinutes % 60}분 뒤에 붙어요';
      } else {
        text = '오늘은 더 붙지 않아요';
      }
      // 묶음 78 #309: 「새 의뢰가 붙기까지」 빈칸 (흐린 넓은 카드)
      return QuestCard(
        key: Key('errandEmpty_$slot'),
        seed: slot + 7,
        title: text,
        done: false,
        icon: const Icon(Icons.hourglass_bottom_rounded, color: kInkSoft, size: 30),
      );
    }
    final progress = c.errandProgress(slot);
    final done = s.accepted && progress >= t.target;
    return SmallNote(
      key: Key('errandNote_$slot'),
      npc: _npcOf(t),
      title: t.title,
      seed: slot + (s.templateId?.length ?? 0),
      ratio: s.accepted ? progress / t.target : null,
      progress: s.accepted
          ? '${comma(progress)} / ${comma(t.target)}${t.unit}'
          : '수락 전',
      glow: done,
      sealed: s.accepted && !done,
      reward: t.rewardLabel,
      icon: _npcOf(t) == null ? const GameIcon('board', size: 36) : null,
      button: done ? '받기' : (!s.accepted ? '수락하기' : null),
      onTap: done
          ? () => _claim(t)
          : () => showErrandDetail(context, c, slot),
    );
  }
}

/// 길드 의뢰 상세 창 (큰 양피지): 이름·설명·진행·보상·남은 시간 + 수락/포기/보상 받기.
/// 수락 도장 「쿵」은 여기서
Future<void> showErrandDetail(
        BuildContext context, AppController c, int slot) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheet) => TourScreenMark(
        name: 'errandDetail',
        child: _ErrandDetail(controller: c, slot: slot),
      ),
    );

class _ErrandDetail extends StatefulWidget {
  const _ErrandDetail({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  State<_ErrandDetail> createState() => _ErrandDetailState();
}

class _ErrandDetailState extends State<_ErrandDetail> {
  bool? _wasAccepted;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          final slot = widget.slot;
          final s = c.board.slots[slot];
          final t = BoardRules.template(s.templateId, level: c.player.level.level);
          if (t == null) return const SizedBox.shrink();
          final progress = c.errandProgress(slot);
          final done = s.accepted && progress >= t.target;
          final stampIn = _wasAccepted == false && s.accepted;
          _wasAccepted = s.accepted;
          return _DetailSheet(
            seed: slot,
            stamp: done
                ? null
                : s.accepted
                    ? WaxSeal(key: ValueKey('seal_$slot'), stampIn: stampIn, size: 42)
                    : null,
            title: t.title,
            line: switch ((_npcOf(t), s.accepted)) {
              (final n?, false) =>
                '${josa(VillageRules.npc(n).name, '이/가')} 붙인 쪽지예요. 수락하면 그때부터 세요.',
              (_, true) => '수락했어요. 끝내면 쪽지가 빛나요.',
              _ => '수락하면 그때부터 세요.',
            },
            ratio: s.accepted ? progress / t.target : null,
            progress: s.accepted
                ? '${comma(progress)} / ${comma(t.target)}${t.unit}'
                : null,
            rewards: ErrandRewards(t: t),
            timeLeft: '자정까지 ${_untilMidnight(c.now)}',
            actions: [
              // 묶음 47 #239: 「포기」는 왼쪽에 붉은 테두리 작은 버튼, 누르면 확인 창
              if (s.accepted && !done) ...[
                _AbandonButton(
                  key: Key('errandAbandon_$slot'),
                  onConfirmed: () async {
                    await c.abandonErrand(slot);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: GoldButton(
                  key: Key(!s.accepted
                      ? 'errandAccept_$slot'
                      : done
                          ? 'errandClaim_$slot'
                          : 'errandWait_$slot'),
                  label: !s.accepted
                      ? '수락하기'
                      : done
                          ? '보상 받기'
                          : '진행 중',
                  height: 44,
                  fontSize: 15,
                  onPressed: !s.accepted
                      ? () async {
                          await c.acceptErrand(slot);
                          // 도장이 「쿵」 찍힌 걸 보고 닫힌다
                          await Future<void>.delayed(
                              const Duration(milliseconds: 1100));
                          if (context.mounted) Navigator.of(context).maybePop();
                        }
                      : done
                          ? () async {
                              final ok = await c.claimErrand(slot);
                              if (!context.mounted) return;
                              Navigator.of(context).maybePop();
                              if (ok) {
                                showTopNotice(
                                    context, '의뢰 완료! ${t.rewardLabel}');
                              }
                            }
                          : null,
                ),
              ),
            ],
          );
        },
      );
}

/// 길드 의뢰 보상 띠: 금화·마석·재료를 아이콘과 함께 (11-11 #46)
/// 묶음 45 #231: 마을 사람 쪽지의 그 사람
Npc? _npcOf(ErrandTemplate t) =>
    Npc.values.where((n) => n.name == t.npc).firstOrNull;

class ErrandRewards extends StatelessWidget {
  const ErrandRewards({super.key, required this.t});

  final ErrandTemplate t;

  @override
  Widget build(BuildContext context) => NoteRewards(items: [
        if (t.exp > 0)
          (
            const Icon(Icons.auto_awesome_rounded, size: 15, color: kInkSoft),
            '경험치 ${t.exp}'
          ),
        if (t.gold > 0)
          (
            const GameIcon('gold',
                size: 15, fallback: Icons.monetization_on_rounded),
            '금화 ${t.gold}'
          ),
        if (t.manaStones > 0)
          (
            const GameIcon('mana_stone',
                size: 15, fallback: Icons.diamond_rounded),
            '마석 ${t.manaStones}'
          ),
        for (final e in t.materials.entries)
          (MaterialIcon(e.key, size: 15), '${Materials.info(e.key).name} ${e.value}'),
      ]);
}

/// 묶음 47 #239: 의뢰 포기 버튼 (붉은 테두리, 누르면 확인 창)
class _AbandonButton extends StatelessWidget {
  const _AbandonButton({super.key, required this.onConfirmed});

  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFA8322A),
          side: const BorderSide(color: Color(0xFFB8453A), width: 1.6),
          backgroundColor: const Color(0x22B8453A),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => GameAlert(
              title: const Text('이 의뢰를 포기할까요?'),
              content: const KText('지금까지 센 것은 사라지고, 2시간 뒤 새 의뢰가 붙어요.'),
              actions: [
                TextButton(
                    key: const Key('errandAbandonNo'),
                    onPressed: () => Navigator.of(d).pop(false),
                    child: const Text('계속하기')),
                TextButton(
                    key: const Key('errandAbandonYes'),
                    onPressed: () => Navigator.of(d).pop(true),
                    child: const Text('포기하기')),
              ],
            ),
          );
          if (ok == true) await onConfirmed();
        },
        child: const Text('포기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}
