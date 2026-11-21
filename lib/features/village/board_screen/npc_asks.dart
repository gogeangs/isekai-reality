part of '../board_screen.dart';

/// 묶음 66 #268: 게시판 맨 아래 「마을 사람 부탁」 — 다 한 부탁이 맨 위, 누르면 그 사람 부탁 창
class _NpcAskPanel extends StatelessWidget {
  const _NpcAskPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final list = [...controller.activeAsks];
    // 묶음 69 #286: 아직 안 받은 새 부탁도 함께 (누르면 그 사람 부탁 창에서 받기)
    final fresh = controller.newAsks;
    final notes = _npcNotes(controller);
    if (list.isEmpty && fresh.isEmpty && notes.isEmpty) return const SizedBox.shrink();
    bool done(NpcAskLine a) => _askDone(a);
    final doneList = [for (final a in list) if (done(a)) a];
    final going = [for (final a in list) if (!done(a)) a];
    String title(Npc n, AskKind k) => switch (k) {
          AskKind.big => VillageRules.npc(n).name,
          AskKind.small => '${VillageRules.npc(n).name} · 작은 부탁',
          AskKind.special => '${VillageRules.npc(n).name} · 특별한 부탁',
        };
    return Padding(
      key: const Key('boardNpcAsks'),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BoardPlaque('마을 사람 부탁', note: fresh.isEmpty ? '받은 부탁 ${list.length}개' : '새 부탁 ${fresh.length}개 · 받은 부탁 ${list.length}개'),
        const SizedBox(height: 4),
        NoteGrid(children: [
          // 순서: 다 한 부탁(금빛) → 새 부탁 → 진행 중
          for (final (i, a) in doneList.indexed) _ask(context, a, i, done(a)),
          for (final (i, f) in fresh.indexed)
            SmallNote(
              key: Key('boardNew_${f.npc.name}_${f.kind.name}'),
              npc: f.npc,
              title: title(f.npc, f.kind),
              seed: i + 31,
              ribbon: '새 부탁',
              progress: '새로 온 부탁이에요',
              button: '부탁 듣기',
              onTap: () => showNpcRequestSheet(context, controller, f.npc, kind: f.kind),
            ),
          for (final (i, a) in going.indexed) _ask(context, a, i + doneList.length, done(a)),
        ]),
        // 묶음 77 #350: 그 아래 지금 마을 사람 쪽지
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          const BoardPlaque('마을 사람 쪽지'),
          const SizedBox(height: 4),
          NoteGrid(children: [
            for (final i in _errandOrder(controller, notes)) _ErrandNote(controller: controller, slot: i),
          ]),
        ],
      ]),
    );
  }

  Widget _ask(BuildContext context, NpcAskLine a, int i, bool isDone) => SmallNote(
        key: Key('boardAsk_${a.npc.name}_${a.kind.name}'),
        npc: a.npc,
        title: switch (a.kind) {
          AskKind.big => VillageRules.npc(a.npc).name,
          AskKind.small => '${VillageRules.npc(a.npc).name} · 작은 부탁',
          AskKind.special => '${VillageRules.npc(a.npc).name} · 특별한 부탁',
        },
        seed: i + 11,
        ratio: a.progress.isEmpty
            ? null
            : a.progress.fold<double>(0, (t, x) => t + (x.step.need <= 0 ? 1 : (x.shown / x.step.need).clamp(0.0, 1.0))) / a.progress.length,
        progress: isDone
            ? '다 했어요!'
            : [for (final x in a.progress) '${x.step.label} ${comma(x.shown)}/${comma(x.step.need)}'].join(' · '),
        glow: isDone,
        onTap: () => showNpcRequestSheet(context, controller, a.npc, kind: a.kind),
      );
}
