import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import 'alchemy_screen.dart' show PotionIcon;

/// 공방 변환 (11-11 #74): 변환대 1칸 · 상위 변환 · 같은 등급 교환 · 마석 정제 · 분해
class ConvertPanel extends StatelessWidget {
  const ConvertPanel({super.key, required this.controller});

  final AppController controller;

  AppController get c => controller;

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _start(BuildContext context, ConvertPlan p) async {
    final ok = await c.startConvert(p);
    if (!context.mounted) return;
    _snack(
        context,
        !ok
            ? '재료나 금화가 모자라요.'
            : p.minutes == 0
                ? '분해했어요. ${_outLabel(p)}'
                : '변환대에 올렸어요. ${p.minutes}분 뒤에 꺼낼 수 있어요.');
  }

  static String _outLabel(ConvertPlan p) => [
        for (final e in p.get.entries) '${Materials.info(e.key).name} ${e.value}',
        if (p.getManaStones > 0) '마석 ${p.getManaStones}',
      ].join(' · ');

  static String _inLabel(ConvertPlan p) => [
        for (final e in p.give.entries) '${Materials.info(e.key).name} ${e.value}',
        if (p.giveManaStones > 0) '마석 ${p.giveManaStones}',
      ].join(' + ');

  @override
  Widget build(BuildContext context) {
    final job = c.convertJob;
    final busy = job != null;
    final owned = c.player.materials;
    final commons = [
      for (final m in ConvertRules.commons)
        if ((owned[m] ?? 0) > 0) m,
    ];
    final rares = [
      for (final m in ConvertRules.rares)
        if ((owned[m] ?? 0) > 0) m,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JobCard(controller: c),
        const SizedBox(height: 10),
        _Section(
          key: const Key('convUpgrade'),
          title: '상위 변환',
          note: '같은 재료 ${ConvertRules.upgradeCount}개 → 그 몬스터의 귀한 재료 1개',
          children: [
            for (final m in commons)
              if (ConvertRules.upgrade(m) case final p?)
                _PlanRow(
                  icon: MaterialIcon(p.get.keys.first, size: 34),
                  title: Materials.info(p.get.keys.first).name,
                  sub: '${_inLabel(p)} · 금화 ${p.gold} · ${p.minutes}분',
                  label: '변환',
                  onPressed: !busy && c.canConvert(p) ? () => _start(context, p) : null,
                ),
            if (commons.isEmpty) const _Hint('몬스터 재료를 모으면 여기에 보여요.'),
          ],
        ),
        _Section(
          key: const Key('convExchange'),
          title: '같은 등급 교환',
          note: '남는 재료 ${ConvertRules.exchangeCount}개 → 고른 재료 1개 (일반은 일반끼리, 귀한 것은 귀한 것끼리)',
          children: [
            for (final m in [...commons, ...rares])
              if ((owned[m] ?? 0) >= ConvertRules.exchangeCount)
                _PlanRow(
                  icon: MaterialIcon(m, size: 34),
                  title: '${Materials.info(m).name} ${owned[m]}개',
                  sub: ConvertRules.isRare(m)
                      ? '금화 ${ConvertRules.exchangeGoldRare} · ${ConvertRules.exchangeMinutesRare}분'
                      : '금화 ${ConvertRules.exchangeGoldCommon} · ${ConvertRules.exchangeMinutesCommon}분',
                  label: '교환',
                  onPressed: busy ? null : () => _pickExchange(context, m),
                ),
            if (![...commons, ...rares]
                .any((m) => (owned[m] ?? 0) >= ConvertRules.exchangeCount))
              const _Hint('같은 재료가 2개 이상 있으면 바꿀 수 있어요.'),
          ],
        ),
        _Section(
          key: const Key('convRefine'),
          title: '마석 정제',
          note: '마석 ${ConvertRules.refineManaStones} + 그 속성 코어 1 → 속성 마석 1. 속성 마석은 공방에서 공격 속성 물약을 만들 때 써요.',
          children: [
            for (final e in Element.values)
              _PlanRow(
                key: Key('refine_${e.name}'),
                icon: MaterialIcon(Materials.elementStone(e), size: 34),
                title: Materials.info(Materials.elementStone(e)).name,
                sub: '${_inLabel(ConvertRules.refine(e))} · 금화 ${ConvertRules.refineGold} · ${ConvertRules.refineMinutes}분'
                    ' (코어 ${owned[Materials.elementCore(e)] ?? 0}개)',
                label: '정제',
                onPressed: !busy && c.canConvert(ConvertRules.refine(e))
                    ? () => _start(context, ConvertRules.refine(e))
                    : null,
              ),
          ],
        ),
        _Section(
          key: const Key('convDecompose'),
          title: '분해',
          note: '쓰지 않는 물약 → 약초 (좋음·최상은 마석도), 귀한 재료 1 → 마석 ${ConvertRules.decomposeRareStones}, '
              '일반 재료 ${ConvertRules.decomposeCommonCount} → 마석 1. 금화 없이 바로 끝나요.',
          children: [
            for (final e in c.alchemy.potions.entries)
              if (e.value > 0)
                _PlanRow(
                  icon: PotionIcon(
                      potion: AlchemyRules.parseKey(e.key)?.id,
                      suspicious: e.key.startsWith('?:'),
                      size: 34),
                  title: '${c.potionName(e.key)} ${e.value}개',
                  sub: '→ ${_outLabel(ConvertRules.decomposePotion(e.key))}',
                  label: '분해',
                  onPressed: () => _confirmDecompose(
                      context, ConvertRules.decomposePotion(e.key), c.potionName(e.key)),
                ),
            for (final m in [...commons, ...rares])
              if (c.canConvert(ConvertRules.decomposeMaterial(m)))
                _PlanRow(
                  icon: MaterialIcon(m, size: 34),
                  title: '${Materials.info(m).name} ${owned[m]}개',
                  sub: '${_inLabel(ConvertRules.decomposeMaterial(m))} → ${_outLabel(ConvertRules.decomposeMaterial(m))}',
                  label: '분해',
                  onPressed: () => _confirmDecompose(context,
                      ConvertRules.decomposeMaterial(m), Materials.info(m).name),
                ),
          ],
        ),
        const SizedBox(height: 10),
        const _Locked(
          title: '연금술사 우대',
          lines: ['상위 변환에 재료가 덜 들어요', '가끔 하나 더 나와요', '변환 시간이 짧아요'],
        ),
      ],
    );
  }

  Future<void> _confirmDecompose(
      BuildContext context, ConvertPlan p, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('${josa(name, '을/를')} 분해할까요?'),
        content: KText('돌려받는 것: ${_outLabel(p)}\n분해한 것은 되돌릴 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('그만두기')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('분해하기')),
        ],
      ),
    );
    if (ok == true && context.mounted) await _start(context, p);
  }

  Future<void> _pickExchange(BuildContext context, MaterialId from) async {
    final rare = ConvertRules.isRare(from);
    final targets = [
      for (final m in rare ? ConvertRules.rares : ConvertRules.commons)
        if (m != from) m,
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            children: [
              Text('${Materials.info(from).name} ${ConvertRules.exchangeCount}개를 무엇으로?',
                  style: AppText.title(18)),
              const SizedBox(height: 8),
              for (final to in targets)
                if (ConvertRules.exchange(from, to) case final p?)
                  _PlanRow(
                    icon: MaterialIcon(to, size: 34),
                    title: Materials.info(to).name,
                    sub: '금화 ${p.gold} · ${p.minutes}분',
                    label: '고르기',
                    onPressed: c.canConvert(p)
                        ? () async {
                            Navigator.of(sheet).pop();
                            await _start(context, p);
                          }
                        : null,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 변환대 상태 (비어 있음 · 진행 중 · 다 됨)
class _JobCard extends StatelessWidget {
  const _JobCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final job = c.convertJob;
    final ready = c.convertReady;
    return OrnatePanel(
      key: const Key('convertTable'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GameIcon('convert_table', size: 36, fallback: Icons.science_rounded),
            const SizedBox(width: 8),
            Text('변환대', style: AppText.title(17)),
          ]),
          const SizedBox(height: 6),
          if (job == null)
            const KText('비어 있어요. 아래에서 변환을 골라 올려요. 한 번에 하나씩 해요.',
                style: TextStyle(color: AppColors.text, fontSize: 13))
          else ...[
            KText(
                '${ConvertKind.values.firstWhere((k) => k.name == job.kind, orElse: () => ConvertKind.upgrade).label} · '
                '${[
                  for (final e in job.get.entries)
                    if (Materials.byName(e.key) case final m?)
                      '${Materials.info(m).name} ${e.value}',
                ].join(' · ')}',
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
            const SizedBox(height: 6),
            GlowBar(
              ratio: () {
                final total = job.readyAt.difference(job.startedAt).inSeconds;
                final done = c.now.difference(job.startedAt).inSeconds;
                return total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
              }(),
              colors: BarColors.exp,
              height: 7,
            ),
            const SizedBox(height: 4),
            Text(
                ready
                    ? '다 됐어요!'
                    : '${job.readyAt.difference(c.now).inMinutes + 1}분 남았어요',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (ready) ...[
              const SizedBox(height: 8),
              GoldButton(
                key: const Key('collectConvert'),
                label: '꺼내기',
                height: 44,
                onPressed: () async {
                  final j = await c.collectConvert();
                  if (j == null || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('변환한 재료를 가방에 넣었어요.')));
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {super.key, required this.title, required this.note, required this.children});

  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OrnatePanel(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: AppColors.goldBright,
              collapsedIconColor: AppColors.goldBright,
              title: Text(title, style: AppText.title(17)),
              subtitle: KText(note,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              children: children,
            ),
          ),
        ),
      );
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String title;
  final String sub;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(14, color: AppColors.text)),
                KText(sub,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            style: gameButtonStyle(gold: true).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(64, 34)),
              padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10)),
              textStyle: const WidgetStatePropertyAll(TextStyle(
                  fontFamily: 'Title', fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            onPressed: onPressed,
            child: Text(label),
          ),
        ]),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: KText(text,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
}

/// 직업 각성 뒤에 열리는 것 (11-11 #74): 자물쇠와 함께 흐리게
class _Locked extends StatelessWidget {
  const _Locked({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => LockedJobPanel(title: title, lines: lines);
}

/// 직업 각성 뒤에 열리는 능력 목록
class LockedJobPanel extends StatelessWidget {
  const LockedJobPanel({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.6,
        child: OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.lock_rounded, color: AppColors.goldBright, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: AppText.title(16))),
                const Text('직업 각성 뒤 열림',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 4),
              for (final l in lines)
                KText('· $l',
                    style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
            ],
          ),
        ),
      );
}

/// 연금술사 직업 (11-11 #74): 레벨로 열리는 능력과 숙련도 단계. 직업 각성 전에는 잠김.
class AlchemistPanel extends StatelessWidget {
  const AlchemistPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => LockedJobPanel(
        key: const Key('alchemistLocked'),
        title: '연금술사',
        lines: [
          '숙련도: 견습 → 숙련 → 장인 → 대가 (물약을 끓이고 변환할수록 올라요)',
          for (final a in AlchemistRules.abilities)
            '${a.label} · Lv.${a.level} · ${a.rank.label}',
          '호문쿨루스와 함께: 끓이기·변환이 빨라지고, 속성 마석을 먹이면 속성이 생겨요',
        ],
      );
}
