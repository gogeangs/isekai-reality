import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'npc_header.dart';

/// 묶음 42 #226: 마을 사람 부탁 · 사연 화면 조각들

const Color _ok = Color(0xFF7FD48A);

/// 선물 키 → 글 ('금화 100' · '회복 물약 2' · '레시피 쪽지 1')
String npcGiftLabel(AppController c, String k, int v) {
  if (k == Wallet.gold) return '금화 $v';
  if (k == Wallet.manaStone) return '마석 $v';
  if (k == 'note') return '레시피 쪽지 $v';
  if (k.startsWith('item:')) {
    for (final it in ShopItem.values) {
      if (it.name == k.substring(5)) return '${c.itemName(it)} $v';
    }
  }
  if (Materials.byName(k) case final m?) return '${Materials.info(m).name} $v';
  return k;
}

String npcRewardLabel(AppController c, NpcRequest r) => [
      for (final e in r.gifts.entries) npcGiftLabel(c, e.key, e.value),
      if (r.special != null) '특별한 선물',
    ].join(' · ');

/// 묶음 45: 부탁 종류마다 색 (큰 부탁 금빛 · 작은 부탁 하늘빛 · 특별한 부탁 보랏빛)
({List<Color> fill, Color edge, Color glow, Color ink, String label}) askLook(
        AskKind k) =>
    switch (k) {
      AskKind.big => (
          fill: const [Color(0xFFFFE7A3), Color(0xFFE0A93A)],
          edge: const Color(0xFF6A4410),
          glow: const Color(0xAAFFD36A),
          ink: AppColors.goldInk,
          label: '부탁',
        ),
      AskKind.small => (
          fill: const [Color(0xFFD8F4FF), Color(0xFF5DB6E4)],
          edge: const Color(0xFF1C4A68),
          glow: const Color(0xAA8FD8FF),
          ink: const Color(0xFF0E2A40),
          label: '작은 부탁',
        ),
      AskKind.special => (
          fill: const [Color(0xFFF0DEFF), Color(0xFFA06EE6)],
          edge: const Color(0xFF3E1F6E),
          glow: const Color(0xAAC9A2FF),
          ink: const Color(0xFF2A1048),
          label: '특별한 부탁',
        ),
    };

/// 시설 맨 위 마을 사람 아래 한 줄: 부탁마다 「부탁 듣기」 · 진행 · 「다 했어요」
/// (묶음 45: 큰 부탁 · 특별한 부탁 · 작은 부탁이 함께 있을 수 있다)
class NpcRequestBar extends StatelessWidget {
  const NpcRequestBar({super.key, required this.controller, required this.npc});

  final AppController controller;
  final Npc npc;

  Widget _chip(BuildContext context, AskKind kind) {
    final c = controller;
    final offered = switch (kind) {
      AskKind.big => c.requestOffer(npc) != null,
      AskKind.small => c.smallOffer(npc) != null,
      AskKind.special => c.relicOffer(npc) != null,
    };
    final active = switch (kind) {
      AskKind.big => c.requestActive(npc) != null,
      AskKind.small => c.smallActive(npc) != null,
      AskKind.special => c.relicActive(npc) != null,
    };
    if (!offered && !active) return const SizedBox.shrink();
    final ready = switch (kind) {
      AskKind.big => c.requestReady(npc),
      AskKind.small => c.smallReady(npc),
      AskKind.special => c.relicReady(npc),
    };
    final tag = kind == AskKind.big ? '' : '_${kind.name}';
    if (offered) {
      return _SmallGold(
        key: Key('npcAsk_${npc.name}$tag'),
        kind: kind,
        label: kind == AskKind.big ? '부탁 듣기' : askLook(kind).label,
        icon: kind == AskKind.special
            ? Icons.star_rounded
            : Icons.priority_high_rounded,
        onTap: () => showNpcRequestSheet(context, c, npc, kind: kind),
      );
    }
    if (ready) {
      return _SmallGold(
        key: Key('npcDone_${npc.name}$tag'),
        kind: kind,
        label: '다 했어요',
        icon: Icons.check_rounded,
        onTap: () => finishNpcAsk(context, c, npc, kind),
      );
    }
    final p = switch (kind) {
      AskKind.big => c.requestProgress(npc),
      AskKind.small => c.smallProgress(npc),
      AskKind.special => c.relicProgress(npc),
    };
    if (p.isEmpty) return const SizedBox.shrink();
    final first = p.firstWhere((x) => !x.done, orElse: () => p.first);
    final look = askLook(kind);
    final head = switch (kind) {
      AskKind.big => '부탁',
      AskKind.small => '작은 부탁',
      AskKind.special => '특별한 부탁 ${c.relicStage(npc) + 1}단계',
    };
    return GestureDetector(
      key: Key('npcReq_${npc.name}$tag'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showNpcRequestSheet(context, c, npc, kind: kind),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
        decoration: BoxDecoration(
          color: const Color(0xCC0B0D26),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: look.fill.last.withValues(alpha: 0.8)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              kind == AskKind.special
                  ? Icons.star_rounded
                  : Icons.assignment_rounded,
              size: 14,
              color: look.fill.first),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$head · ${first.step.label} ${comma(first.shown)}/${comma(first.step.need)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFFE6DCC4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final chips = [
            for (final k in AskKind.values) _chip(context, k),
          ].where((w) => w is! SizedBox).toList();
          if (chips.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
          );
        },
      );
}

class _SmallGold extends StatelessWidget {
  const _SmallGold(
      {super.key,
      required this.label,
      required this.icon,
      required this.onTap,
      this.kind = AskKind.big});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AskKind kind;

  @override
  Widget build(BuildContext context) {
    final look = askLook(kind);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: look.fill,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: look.edge),
          boxShadow: [BoxShadow(color: look.glow, blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: look.ink),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: look.ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

/// 부탁 창 안에 보여 줄 것 (종류마다)
class _AskView {
  const _AskView({
    required this.offered,
    required this.say,
    required this.steps,
    required this.progress,
    required this.reward,
    required this.ready,
    this.stages = const [],
    this.stage = 0,
    this.relic,
  });

  final bool offered;
  final String say;
  final List<NpcRequestStep> steps;
  final List<NpcStepProgress> progress;
  final String reward;
  final bool ready;

  /// 특별한 부탁: 단계 이름(할 일 줄) · 지금 단계
  final List<String> stages;
  final int stage;
  final NpcRelic? relic;
}

_AskView? _viewOf(AppController c, Npc npc, AskKind kind) {
  switch (kind) {
    case AskKind.big:
      final offer = c.requestOffer(npc);
      final r = offer ?? c.requestActive(npc);
      if (r == null) return null;
      return _AskView(
        offered: offer != null,
        say: r.say,
        steps: r.steps,
        progress: offer == null ? c.requestProgress(npc) : const [],
        reward: npcRewardLabel(c, r),
        ready: offer == null && c.requestReady(npc),
      );
    case AskKind.small:
      final offer = c.smallOffer(npc);
      final s = offer ?? c.smallActive(npc);
      if (s == null) return null;
      return _AskView(
        offered: offer != null,
        say: c.smallSay(npc),
        steps: s.steps,
        progress: offer == null ? c.smallProgress(npc) : const [],
        reward: '경험치 ${NpcSmallRules.smallExp}',
        ready: offer == null && c.smallReady(npc),
      );
    case AskKind.special:
      final offer = c.relicOffer(npc);
      final r = offer ?? c.relicActive(npc);
      if (r == null) return null;
      final stage = offer == null ? c.relicStage(npc) : 0;
      return _AskView(
        offered: offer != null,
        say: offer != null ? r.say : r.stages[stage].line,
        steps: r.stages[stage].steps,
        progress: offer == null ? c.relicProgress(npc) : const [],
        reward: r.name,
        ready: offer == null && c.relicReady(npc),
        stages: [
          for (final st in r.stages) st.steps.map((x) => x.label).join(' · '),
        ],
        stage: stage,
        relic: r,
      );
  }
}

/// 부탁 창: 얼굴 · 부탁 말 · 할 일(진행) · 보상 · 「받기」·「나중에」 (받은 뒤엔 진행만).
/// 묶음 45: 작은 부탁 · 특별한 부탁도 같은 창 (이름 옆 표시, 특별한 부탁은 단계)
Future<void> showNpcRequestSheet(BuildContext context, AppController c, Npc npc,
    {AskKind kind = AskKind.big}) {
  if (_viewOf(c, npc, kind) == null) return Future.value();
  final info = VillageRules.npc(npc);
  final look = askLook(kind);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final v = _viewOf(c, npc, kind);
          if (v == null) return const SizedBox(height: 40);
          return SingleChildScrollView(
            key: const Key('npcRequestSheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  NpcFace(npc: npc, size: 52),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${info.name}의 부탁',
                            style: AppText.title(18)),
                        Text(info.role,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (kind != AskKind.big)
                    Container(
                      key: Key('askTag_${kind.name}'),
                      padding: const EdgeInsets.fromLTRB(9, 4, 9, 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: look.fill),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: look.edge),
                      ),
                      child: Text(look.label,
                          style: TextStyle(
                              color: look.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E7CC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB08A4A)),
                  ),
                  child: KText(v.say,
                      key: const Key('npcRequestSay'),
                      style: const TextStyle(
                          color: Color(0xFF3A2614),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                const Text('할 일',
                    style: TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                if (v.stages.isNotEmpty)
                  // 특별한 부탁: 단계를 차례대로 (지난 단계는 체크, 다음 단계는 흐리게)
                  for (final (i, label) in v.stages.indexed)
                    if (i == v.stage && !v.offered)
                      for (final (j, s) in v.steps.indexed)
                        _StepRow(
                          key: Key('npcStep_$j'),
                          label: '${i + 1}단계 · ${s.label}',
                          have: v.progress[j].shown,
                          need: s.need,
                        )
                    else
                      _StageRow(
                        key: Key('npcStage_$i'),
                        label: '${i + 1}단계 · $label',
                        done: !v.offered && i < v.stage,
                      )
                else
                  for (final (i, s) in v.steps.indexed)
                    _StepRow(
                      key: Key('npcStep_$i'),
                      label: s.label,
                      have: v.offered ? null : v.progress[i].shown,
                      need: s.need,
                    ),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('보상',
                      style: TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  if (v.relic != null) ...[
                    Image.asset('assets/images/${v.relic!.asset}.webp',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.card_giftcard_rounded,
                            size: 18,
                            color: AppColors.goldBright)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(v.reward,
                        key: const Key('npcReward'),
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                if (v.steps.any((s) => s.kind == RequestStepKind.deliver) ||
                    (v.relic?.stages.last.steps
                            .any((s) => s.kind == RequestStepKind.deliver) ??
                        false)) ...[
                  const SizedBox(height: 6),
                  const Text('가져오는 재료는 「다 했어요」를 누를 때 건네요.',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                if (v.offered)
                  Row(children: [
                    Expanded(
                      child: FrameButton(
                        key: const Key('npcLater'),
                        label: '나중에',
                        height: 48,
                        onPressed: () => Navigator.of(sheet).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GoldButton(
                        key: const Key('npcAccept'),
                        label: '받기',
                        height: 48,
                        fontSize: 18,
                        onPressed: () async {
                          switch (kind) {
                            case AskKind.big:
                              await c.acceptRequest(npc);
                            case AskKind.small:
                              await c.acceptSmall(npc);
                            case AskKind.special:
                              await c.acceptRelic(npc);
                          }
                          if (sheet.mounted) Navigator.of(sheet).pop();
                        },
                      ),
                    ),
                  ])
                else if (v.ready)
                  GoldButton(
                    key: const Key('npcDoneSheet'),
                    label: '다 했어요',
                    height: 48,
                    fontSize: 18,
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      finishNpcAsk(context, c, npc, kind);
                    },
                  )
                else
                  FrameButton(
                    key: const Key('npcClose'),
                    label: '닫기',
                    height: 48,
                    onPressed: () => Navigator.of(sheet).pop(),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _StageRow extends StatelessWidget {
  const _StageRow({super.key, required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18, color: done ? _ok : AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: done ? AppColors.text : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow(
      {super.key, required this.label, required this.have, required this.need});

  final String label;

  /// 받기 전이면 null (진행 없이 할 일만)
  final int? have;
  final int need;

  @override
  Widget build(BuildContext context) {
    final done = have != null && have! >= need;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18, color: done ? _ok : AppColors.gold),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        if (have != null)
          Text('${comma(have!.clamp(0, need))}/${comma(need)}',
              style: TextStyle(
                  color: done ? _ok : AppColors.goldBright,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// 「다 했어요」 (종류마다)
Future<void> finishNpcAsk(
    BuildContext context, AppController c, Npc npc, AskKind kind) async {
  switch (kind) {
    case AskKind.big:
      return finishNpcRequest(context, c, npc);
    case AskKind.small:
      final done = await c.completeSmall(npc);
      if (done == null || !context.mounted) return;
      await showNpcThanksDialog(context, npc, done.thanks, got: done.got);
      // 가끔 그 사람 전용 퀘스트(특별한 부탁)가 바로 이어짐
      if (done.relicOffered && context.mounted) {
        await showNpcRequestSheet(context, c, npc, kind: AskKind.special);
      }
    case AskKind.special:
      final r = await c.completeRelic(npc);
      if (r == null || !context.mounted) return;
      await showNpcRelicDialog(context, r);
  }
}

/// 작은 부탁을 끝냈을 때 고맙다는 한마디 (사연 없음)
Future<void> showNpcThanksDialog(BuildContext context, Npc npc, String thanks,
    {List<String> got = const []}) {
  final info = VillageRules.npc(npc);
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC05060F),
    builder: (d) => Dialog(
      key: const Key('npcThanksDialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        NpcFace(npc: npc, size: 84),
        const SizedBox(height: 8),
        Text(info.name, style: AppText.title(20)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E7CC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB08A4A), width: 1.5),
          ),
          child: KText('「$thanks」',
              key: const Key('npcThanksText'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF3A2614),
                  fontSize: 15.5,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
        ),
        if (got.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('받은 것 · ${got.join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 14),
        GoldButton(
          key: const Key('npcThanksOk'),
          label: '천만에요',
          height: 50,
          fontSize: 18,
          onPressed: () => Navigator.of(d).pop(),
        ),
      ]),
    ),
  );
}

/// 특별한 부탁을 끝냈을 때: 전용 아이템 (가방 「소중한 물건」)
Future<void> showNpcRelicDialog(BuildContext context, NpcRelic r) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC05060F),
      builder: (d) => Dialog(
        key: const Key('npcRelicDialog'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: OrnatePanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              NpcFace(npc: r.npc, size: 40),
              const SizedBox(width: 8),
              Flexible(
                child: KText('「${r.done}」',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFC9A2FF).withValues(alpha: 0.55),
                  Colors.transparent,
                ]),
              ),
              child: Image.asset('assets/images/${r.asset}.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.card_giftcard_rounded,
                      size: 56,
                      color: AppColors.goldBright)),
            ),
            const SizedBox(height: 10),
            Text(r.name,
                key: const Key('npcRelicName'),
                textAlign: TextAlign.center,
                style: AppText.title(18)),
            const SizedBox(height: 4),
            KText(r.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('가방 「소중한 물건」에 넣었어요',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            GoldButton(
              key: const Key('npcRelicOk'),
              label: '고마워요',
              height: 50,
              fontSize: 18,
              onPressed: () => Navigator.of(d).pop(),
            ),
          ]),
        ),
      ),
    );

/// 「다 했어요」: 보상 → 사연 한 조각(대사 창) → (4번째면) 특별 보상
Future<void> finishNpcRequest(
    BuildContext context, AppController c, Npc npc) async {
  final done = await c.completeRequest(npc);
  if (done == null || !context.mounted) return;
  await showNpcStoryDialog(context, npc, done.request.story, got: done.got);
  final sp = done.special;
  if (sp != null && context.mounted) {
    await showNpcSpecialDialog(context, sp);
  }
}

/// 사연 한 조각 (마을 사람 얼굴 + 대사 창)
Future<void> showNpcStoryDialog(BuildContext context, Npc npc, String story,
    {List<String> got = const []}) {
  final info = VillageRules.npc(npc);
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC05060F),
    builder: (d) => Dialog(
      key: const Key('npcStoryDialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        NpcFace(npc: npc, size: 92),
        const SizedBox(height: 8),
        Text(info.name, style: AppText.title(20)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E7CC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB08A4A), width: 1.5),
          ),
          child: KText('「$story」',
              key: const Key('npcStoryText'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF3A2614),
                  fontSize: 15.5,
                  height: 1.55,
                  fontWeight: FontWeight.w700)),
        ),
        if (got.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('받은 것 · ${got.join(', ')}',
              key: const Key('npcStoryGot'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 6),
        const Text('기록 탭 「마을 사람 이야기」에 남았어요',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        GoldButton(
          key: const Key('npcStoryOk'),
          label: '알겠어요',
          height: 50,
          fontSize: 18,
          onPressed: () => Navigator.of(d).pop(),
        ),
      ]),
    ),
  );
}

/// 4번째 부탁 특별 보상 (칭호 + 물건)
Future<void> showNpcSpecialDialog(BuildContext context, NpcSpecial sp) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC05060F),
      builder: (d) => Dialog(
        key: const Key('npcSpecialDialog'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: OrnatePanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('특별한 선물', style: AppText.title(20)),
            const SizedBox(height: 12),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: 0.45),
                  Colors.transparent,
                ]),
              ),
              child: Image.asset('assets/images/${sp.asset}.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.card_giftcard_rounded,
                      size: 56,
                      color: AppColors.goldBright)),
            ),
            const SizedBox(height: 10),
            Text(sp.name,
                key: const Key('npcSpecialName'),
                textAlign: TextAlign.center,
                style: AppText.title(18)),
            const SizedBox(height: 4),
            KText(sp.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: const Color(0xCC0B0D26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.goldBright),
              ),
              child: Text('칭호 「${TitleRules.info(sp.title).name}」',
                  key: const Key('npcSpecialTitle'),
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 14),
            GoldButton(
              key: const Key('npcSpecialOk'),
              label: '고마워요',
              height: 50,
              fontSize: 18,
              onPressed: () => Navigator.of(d).pop(),
            ),
          ]),
        ),
      ),
    );

/// 상태 탭 의뢰 칸: 받은 마을 사람 부탁 (마을 사람 얼굴로 게시판 의뢰와 구분).
/// 묶음 45: 작은 부탁 · 특별한 부탁(단계 진행)도 함께
class NpcRequestPanel extends StatelessWidget {
  const NpcRequestPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final list = controller.activeAsks;
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            key: const Key('statusRequests'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('마을 사람 부탁', style: AppText.title(16)),
              const SizedBox(height: 6),
              for (final a in list)
                GestureDetector(
                  key: Key(a.kind == AskKind.big
                      ? 'statusReq_${a.npc.name}'
                      : 'statusReq_${a.npc.name}_${a.kind.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showNpcRequestSheet(context, controller, a.npc,
                      kind: a.kind),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC12142E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: askLook(a.kind).fill.last.withValues(alpha: 0.6)),
                    ),
                    child: Row(children: [
                      NpcFace(npc: a.npc, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                switch (a.kind) {
                                  AskKind.big => VillageRules.npc(a.npc).name,
                                  AskKind.small =>
                                    '${VillageRules.npc(a.npc).name} · 작은 부탁',
                                  AskKind.special =>
                                    '${VillageRules.npc(a.npc).name} · 특별한 부탁 '
                                        '${a.stage + 1}/${a.stages}단계',
                                },
                                style: TextStyle(
                                    color: a.kind == AskKind.big
                                        ? AppColors.goldBright
                                        : askLook(a.kind).fill.first,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            for (final x in a.progress)
                              Text(
                                  '${x.step.label} ${comma(x.shown)}/${comma(x.step.need)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: x.done
                                          ? _ok
                                          : AppColors.text,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (a.ready &&
                          (a.kind != AskKind.special || a.stage == a.stages - 1))
                        const Text('다 했어요!',
                            style: TextStyle(
                                color: _ok,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ],
          );
        },
      );
}

/// 기록 탭 「마을 사람 이야기」: 사람마다 조각 4개 (못 본 조각은 ???), 다 모으면 금테
class NpcStoryRecords extends StatelessWidget {
  const NpcStoryRecords({super.key, required this.stories});

  final List<(Npc, List<String?>)> stories;

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('npcStoryRecords'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('마을 사람 이야기', style: AppText.title(19)),
        const SizedBox(height: 8),
        for (final (n, pieces) in stories)
          _NpcStoryCard(npc: n, pieces: pieces),
      ],
    );
  }
}

class _NpcStoryCard extends StatelessWidget {
  const _NpcStoryCard({required this.npc, required this.pieces});

  final Npc npc;
  final List<String?> pieces;

  @override
  Widget build(BuildContext context) {
    final full = pieces.isNotEmpty && pieces.every((p) => p != null);
    final info = VillageRules.npc(npc);
    return Container(
      key: Key('npcStory_${npc.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1E0B8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: full ? const Color(0xFFD9A62E) : const Color(0x99A07840),
            width: full ? 3 : 1),
        boxShadow: full
            ? [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 10),
              ]
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NpcFace(npc: npc, size: 36),
          const SizedBox(width: 8),
          Text(info.name,
              style: AppText.title(16, color: const Color(0xFF6E4C2C))),
          const SizedBox(width: 6),
          Text(info.role,
              style: const TextStyle(
                  color: Color(0xFF8A6A48),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (full) ...[
            const Spacer(),
            const Icon(Icons.auto_awesome_rounded,
                key: Key('npcStoryFull'), size: 18, color: Color(0xFFB8860B)),
          ],
        ]),
        const SizedBox(height: 6),
        for (final (i, p) in pieces.indexed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}',
                  style: AppText.title(14, color: const Color(0xFF6E4C2C))),
              const SizedBox(width: 8),
              Expanded(
                child: KText(p ?? '???',
                    style: TextStyle(
                        color: p == null
                            ? const Color(0xFF9A8466)
                            : const Color(0xFF3A2614),
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]),
    );
  }
}
