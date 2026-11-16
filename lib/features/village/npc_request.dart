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

/// 시설 맨 위 마을 사람 아래 한 줄: 「부탁 듣기」 · 진행 · 「다 했어요」
class NpcRequestBar extends StatelessWidget {
  const NpcRequestBar({super.key, required this.controller, required this.npc});

  final AppController controller;
  final Npc npc;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final offer = c.requestOffer(npc);
          final active = c.requestActive(npc);
          if (offer == null && active == null) return const SizedBox.shrink();
          final ready = c.requestReady(npc);
          final Widget child;
          if (offer != null) {
            child = _SmallGold(
              key: Key('npcAsk_${npc.name}'),
              label: '부탁 듣기',
              icon: Icons.priority_high_rounded,
              onTap: () => showNpcRequestSheet(context, c, npc),
            );
          } else if (ready) {
            child = _SmallGold(
              key: Key('npcDone_${npc.name}'),
              label: '다 했어요',
              icon: Icons.check_rounded,
              onTap: () => finishNpcRequest(context, c, npc),
            );
          } else {
            final p = c.requestProgress(npc);
            final first = p.firstWhere((x) => !x.done, orElse: () => p.first);
            child = GestureDetector(
              key: Key('npcReq_${npc.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showNpcRequestSheet(context, c, npc),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B0D26),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.assignment_rounded,
                      size: 14, color: AppColors.goldBright),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '부탁 · ${first.step.label} ${comma(first.shown)}/${comma(first.step.need)}',
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
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(alignment: Alignment.centerLeft, child: child),
          );
        },
      );
}

class _SmallGold extends StatelessWidget {
  const _SmallGold(
      {super.key, required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFE7A3), Color(0xFFE0A93A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF8A5A14)),
            boxShadow: [
              BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: AppColors.goldInk),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.goldInk,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// 부탁 창: 얼굴 · 부탁 말 · 할 일(진행) · 보상 · 「받기」·「나중에」 (받은 뒤엔 진행만)
Future<void> showNpcRequestSheet(
    BuildContext context, AppController c, Npc npc) {
  final offer = c.requestOffer(npc);
  final r = offer ?? c.requestActive(npc);
  if (r == null) return Future.value();
  final info = VillageRules.npc(npc);
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
          final progress = offer == null
              ? c.requestProgress(npc)
              : const <NpcStepProgress>[];
          final ready = offer == null && c.requestReady(npc);
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
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E7CC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB08A4A)),
                  ),
                  child: KText(r.say,
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
                for (final (i, s) in r.steps.indexed)
                  _StepRow(
                    key: Key('npcStep_$i'),
                    label: s.label,
                    have: offer == null ? progress[i].shown : null,
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
                  Expanded(
                    child: Text(npcRewardLabel(c, r),
                        key: const Key('npcReward'),
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                if (r.steps.any((s) => s.kind == RequestStepKind.deliver)) ...[
                  const SizedBox(height: 6),
                  const Text('가져오는 재료는 「다 했어요」를 누를 때 건네요.',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                if (offer != null)
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
                          await c.acceptRequest(npc);
                          if (sheet.mounted) Navigator.of(sheet).pop();
                        },
                      ),
                    ),
                  ])
                else if (ready)
                  GoldButton(
                    key: const Key('npcDoneSheet'),
                    label: '다 했어요',
                    height: 48,
                    fontSize: 18,
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      finishNpcRequest(context, c, npc);
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

/// 상태 탭 의뢰 칸: 받은 마을 사람 부탁 (마을 사람 얼굴로 게시판 의뢰와 구분)
class NpcRequestPanel extends StatelessWidget {
  const NpcRequestPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final list = controller.activeRequests;
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            key: const Key('statusRequests'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text('마을 사람 부탁', style: AppText.title(16)),
              const SizedBox(height: 6),
              for (final (n, _, p) in list)
                GestureDetector(
                  key: Key('statusReq_${n.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showNpcRequestSheet(context, controller, n),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC12142E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      NpcFace(npc: n, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(VillageRules.npc(n).name,
                                style: const TextStyle(
                                    color: AppColors.goldBright,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                            for (final x in p)
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
                      if (p.every((x) => x.done))
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
