import '../village/npc_header.dart';
import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/element_view.dart' show elementColor;
import '../town/material_view.dart';
import 'convert_panel.dart';
import 'workbench.dart';
import '../../theme/top_notice.dart';
import '../tutorial/feature_tour.dart'
    show TourScreenMark, firstPotionPicked, firstPotionMadeTick;
import '../jobs/job_skill_bar.dart';

/// 연금술 공방 (11-11 #57·#58). 묶음 70 #297·#298: 「작업대 · 레시피」 두 탭
class AlchemyScreen extends StatefulWidget {
  const AlchemyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AlchemyScreen> createState() => _AlchemyScreenState();
}

/// 레시피 갈래 (묶음 70 #298)
enum RecipeGroup {
  all('전체'),
  heal('회복'),
  buff('강화'),
  resist('저항'),
  weapon('공격'),
  etc('기타');

  const RecipeGroup(this.label);
  final String label;

  static RecipeGroup of(PotionId id) => switch (AlchemyRules.info(id).kind) {
        PotionKind.heal || PotionKind.mana || PotionKind.care => heal,
        PotionKind.buff => buff,
        PotionKind.resist => resist,
        PotionKind.weapon => weapon,
        PotionKind.special => etc,
      };
}

class _AlchemyScreenState extends State<AlchemyScreen> {
  RecipeGroup _group = RecipeGroup.all;
  final WorkbenchBus _bus = WorkbenchBus();

  /// 마을 사람 말풍선 (안내)
  String? _tabLine;

  AppController get c => widget.controller;

  @override
  void dispose() {
    _bus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return TourScreenMark(name: 'alchemy', child: Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        interior: 'alchemy', // 묶음 67 #272
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Padding(
            padding: EdgeInsets.fromLTRB(14, top + 6, 14, bottom + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 묶음 75 #318 B안: 위 「작업대」 + 오른쪽 위 둥근 「레시피」 버튼 (탭은 없앰)
                OrnateTopBar(
                  title: '작업대',
                  onBack: () => Navigator.of(context).maybePop(),
                  trailing: _RecipeButton(onTap: () => _openBook(context)),
                ),
                const SizedBox(height: 6),
                NpcHeader(
                  controller: c,
                  npc: Npc.eliel,
                  guide: VillageRules.alchemyGuide(0),
                  tabLine: _tabLine,
                ),
                const SizedBox(height: 6),
                JobSkillBar(
                    controller: widget.controller,
                    places: const [SkillPlace.alchemy]),
                // 묶음 28 #181: 첫 물약 안내 중이면 회복 물약 판이 맨 위에
                if (c.firstPotionGuide) ...[
                  _FirstPotionPanel(controller: c),
                  const SizedBox(height: 8),
                ],
                Expanded(child: AlchemyWorkbench(controller: c, bus: _bus)),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  /// 「아는 레시피」 창 (아래에서)
  Future<void> _openBook(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SizedBox(
          key: const Key('recipeSheet'),
          height: MediaQuery.sizeOf(sheet).height * 0.82,
          child: StatefulBuilder(
            builder: (sheet, set) => ListenableBuilder(
              listenable: c,
              builder: (sheet, _) => Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('아는 레시피', style: AppText.title(19)),
                  const SizedBox(height: 6),
                  Expanded(child: _book(sheet, set)),
                ]),
              ),
            ),
          ),
        ),
      );

  // ───────────── 레시피 (3칸 격자)

  Widget _book(BuildContext context, [StateSetter? set]) {
    final known = c.knownRecipes;
    final groups = [
      RecipeGroup.all,
      for (final g in RecipeGroup.values.skip(1))
        if (known.any((id) => RecipeGroup.of(id) == g)) g,
    ];
    if (!groups.contains(_group)) _group = RecipeGroup.all;
    final shown = [
      for (final id in known)
        if (_group == RecipeGroup.all || RecipeGroup.of(id) == _group) id,
    ];
    return ListView(
      key: const Key('recipeList'),
      padding: EdgeInsets.zero,
      children: [
        if (c.recipeNotes > 0) ...[
          GoldButton(
            label: '레시피 쪽지 읽기 (${c.recipeNotes}장)',
            height: 44,
            fontSize: 16,
            onPressed: () async {
              final id = await c.readNote();
              if (!context.mounted) return;
              showTopNotice(context, id == null
                      ? '더 알아낼 레시피가 없어요.'
                      : '「${AlchemyRules.info(id).name}」의 재료를 알아냈어요!');
            },
          ),
          const SizedBox(height: 8),
        ],
        Text('알아낸 레시피 ${known.length}',
            key: const Key('recipeCount'), style: AppText.title(17)),
        const SizedBox(height: 6),
        if (groups.length > 2)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final g in groups)
              ChoiceChip(
                key: Key('recipeGroup_${g.name}'),
                label: Text(g.label),
                selected: _group == g,
                onSelected: (_) {
                  setState(() => _group = g);
                  set?.call(() {});
                },
                selectedColor: AppColors.gold,
                backgroundColor: AppColors.chipBg,
                labelStyle: TextStyle(
                    color: _group == g ? AppColors.night : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
          ]),
        const SizedBox(height: 8),
        GridView.count(
          key: const Key('recipeGrid'),
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.72,
          children: [
            for (final id in shown)
              _RecipeTile(
                controller: c,
                id: id,
                onTap: () => _showRecipe(context, id),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AlchemistPanel(controller: c),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _showRecipe(BuildContext context, PotionId id) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => _RecipeDetail(
          controller: c,
          id: id,
          onFill: (put) {
            // 지금 보고 있는 가마솥이 비어 있으면 거기, 아니면 빈 가마솥 (넣어 둔 재료도 없는 칸 먼저)
            int? slot;
            final cur = _bus.current;
            if (cur < c.cauldronCount && c.alchemy.brews[cur] == null) slot = cur;
            for (var i = 0; i < c.cauldronCount; i++) {
              if (c.alchemy.brews[i] == null && (_bus.drafts[i]?.isEmpty ?? true)) {
                slot = i;
                break;
              }
            }
            if (slot == null) {
              for (var i = 0; i < c.cauldronCount; i++) {
                if (c.alchemy.brews[i] == null) {
                  slot = i;
                  break;
                }
              }
            }
            if (slot == null) return false;
            // 상세 창 · 레시피 창을 닫고 ①~⑤ 칸이 순서대로 참
            Navigator.of(sheet).pop();
            Navigator.of(context).maybePop();
            _bus.fill(slot, put);
            return true;
          },
        ),
      );
}

/// 레시피 한 칸: 물약 그림 · 이름(두 줄까지) · 「10분 · 3개」.
/// 재료가 다 있으면 초록 점, 쪽지로 알았으면 작은 쪽지, 최상으로 만들어 봤으면 금빛 테두리
class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.controller, required this.id, required this.onTap});

  final AppController controller;
  final PotionId id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = AlchemyRules.info(id);
    final best = c.madeBest(id);
    final noted = !c.recipeDiscovered(id);
    final ready = c.hasRecipeMats(id);
    return GestureDetector(
      key: Key('recipeTile_${id.name}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          color: AppColors.slotBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: best ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35),
              width: best ? 2 : 1),
          boxShadow: best ? const [BoxShadow(color: Color(0x66FFD86B), blurRadius: 6)] : null,
        ),
        child: Stack(children: [
          Column(children: [
            PotionIcon(potion: id, size: 64),
            const SizedBox(height: 4),
            Expanded(
              child: Text(keepAll(info.name),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.2)),
            ),
            Text('${info.minutes}분 · ${info.yields}개',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          if (ready)
            Positioned(
              left: 2,
              top: 0,
              child: Container(
                key: const Key('recipeReadyDot'),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(color: Color(0xFF6BD97A), shape: BoxShape.circle),
              ),
            ),
          if (noted)
            Positioned(
              right: 0,
              top: 0,
              child: Image.asset('assets/images/item_recipe_note.webp',
                  key: const Key('recipeNoteMark'),
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.sticky_note_2_rounded, size: 15, color: AppColors.goldBright)),
            ),
        ]),
      ),
    );
  }
}

/// 레시피 상세: 큰 그림 · 효과 · 재료(가진 수 / 필요) · 시간 · 개수 · 잘 맞는 약초 · 「가마솥에 넣기」
class _RecipeDetail extends StatelessWidget {
  const _RecipeDetail({required this.controller, required this.id, required this.onFill});

  final AppController controller;
  final PotionId id;

  /// 넣을 재료 → 빈 가마솥이 없으면 false
  final bool Function(List<MaterialId>) onFill;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = AlchemyRules.info(id);
    final made = c.recipeDiscovered(id);
    // 만들어 본 레시피만 넣는 순서대로, 쪽지로만 알면 재료 순서로 (순서는 숨김)
    final order = made
        ? info.recipe
        : ([...info.recipe]..sort((a, b) => a.index.compareTo(b.index)));
    final need = <MaterialId, int>{};
    for (final m in order) {
      need[m] = (need[m] ?? 0) + 1;
    }
    int have(MaterialId m) => m == MaterialId.herb
        ? Materials.herbGroup.fold(0, (t, h) => t + c.player.materialCount(h))
        : c.player.materialCount(m);
    final fill = c.recipeFill(id);
    final empty = [for (var i = 0; i < c.cauldronCount; i++) if (c.alchemy.brews[i] == null) i];
    final herb = AlchemyRules.bestHerb(id);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: PotionIcon(potion: id, size: 110)),
            const SizedBox(height: 6),
            Text(info.name, textAlign: TextAlign.center, style: AppText.title(20)),
            const SizedBox(height: 4),
            KText(info.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.4)),
            const SizedBox(height: 10),
            Text(made ? '넣는 순서' : '재료', style: AppText.title(14, color: AppColors.goldBright)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (i, m) in (made ? order : need.keys.toList()).indexed)
                Container(
                  key: Key('recipeNeed_$i'),
                  padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
                  decoration: BoxDecoration(
                    color: AppColors.slotBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: have(m) >= need[m]! ? AppColors.gold.withValues(alpha: 0.4) : AppColors.danger),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (made)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    MaterialIcon(m == MaterialId.herb ? (herb ?? m) : m, size: 26),
                    const SizedBox(width: 3),
                    Text('${Materials.needName(m)} ${have(m)}/${need[m]}',
                        style: TextStyle(
                            color: have(m) >= need[m]! ? AppColors.text : AppColors.danger,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
            const SizedBox(height: 8),
            Text('${info.minutes}분 · ${info.yields}개',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            // 묶음 67 #273: 「약초」 칸에 잘 맞는 약초
            if (info.counts.containsKey(MaterialId.herb) && herb != null)
              Text('잘 맞는 약초: ${Materials.info(herb).name}',
                  key: Key('bestHerb_${id.name}'),
                  style: const TextStyle(color: Color(0xFF9FE3A8), fontSize: 12)),
            const SizedBox(height: 12),
            if (fill == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: KText('재료가 모자라요',
                    key: Key('recipeShort'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700)),
              )
            else if (empty.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: KText('가마솥이 모두 끓고 있어요',
                    key: Key('recipeBusy'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            GoldButton(
              key: const Key('recipeFill'),
              label: fill == null ? '재료 부족' : '채우기',
              height: 46,
              fontSize: 17,
              onPressed: fill == null || empty.isEmpty ? null : () => onFill(fill),
            ),
          ],
        ),
      ),
    );
  }
}

/// 물약 그림 (potion_<이름>.png, 없으면 아이콘)
class PotionIcon extends StatelessWidget {
  const PotionIcon({super.key, this.potion, this.size = 40, this.suspicious = false});

  final PotionId? potion;
  final double size;
  final bool suspicious;

  static Color colorOf(PotionId? p) => switch (p == null ? null : AlchemyRules.info(p).kind) {
        PotionKind.heal => AppColors.danger,
        PotionKind.mana => const Color(0xFF5FA8F0),
        PotionKind.care => const Color(0xFF7FD0A0),
        PotionKind.buff => const Color(0xFFF0A93B),
        // 저항 물약도 속성 색 (11-11: 그림이 오기 전 아이콘)
        PotionKind.resist => elementColor(AlchemyRules.info(p!).element),
        PotionKind.special => AppColors.goldBright,
        PotionKind.weapon => elementColor(AlchemyRules.info(p!).element),
        null => const Color(0xFF9AA6D8),
      };

  @override
  Widget build(BuildContext context) {
    final asset = suspicious || potion == null
        ? 'assets/images/potion_suspicious.webp'
        : AlchemyRules.info(potion!).asset;
    final image = Image.asset(asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
            suspicious ? Icons.help_center_rounded : Icons.science_rounded,
            size: size * 0.8,
            color: colorOf(suspicious ? null : potion)));
    // 저항 물약 병을 속성 색으로 (11-11 #75·3: 새 그림이 오기 전 임시로 색만 입힌다, 독은 그대로)
    final p = potion;
    if (!suspicious && p != null) {
      final info = AlchemyRules.info(p);
      if (info.kind == PotionKind.resist && info.element != Element.poison) {
        return ColorFiltered(
            colorFilter: _tint(elementColor(info.element)), child: image);
      }
    }
    return image;
  }

  /// 명암은 두고 색만 바꾼다
  static ColorFilter _tint(Color c) {
    final r = c.r * 1.35, g = c.g * 1.35, b = c.b * 1.35;
    return ColorFilter.matrix([
      0.30 * r, 0.59 * r, 0.11 * r, 0, 0,
      0.30 * g, 0.59 * g, 0.11 * g, 0, 0,
      0.30 * b, 0.59 * b, 0.11 * b, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }
}

/// 첫 물약 안내 판 (묶음 28 #181): 회복 물약 고르기 → 만들기 (바로 완성)
class _FirstPotionPanel extends StatefulWidget {
  const _FirstPotionPanel({required this.controller});

  final AppController controller;

  @override
  State<_FirstPotionPanel> createState() => _FirstPotionPanelState();
}

class _FirstPotionPanelState extends State<_FirstPotionPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final info = AlchemyRules.info(TutorialOps.firstPotion);
    return ValueListenableBuilder<bool>(
      valueListenable: firstPotionPicked,
      builder: (context, picked, _) => OrnatePanel(
        key: const Key('firstPotionPanel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('첫 물약 만들기', style: AppText.title(17)),
            const SizedBox(height: 8),
            GestureDetector(
              key: const Key('firstPotionPick'),
              onTap: () => firstPotionPicked.value = true,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slotBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: picked
                          ? AppColors.goldBright
                          : AppColors.gold.withValues(alpha: 0.4),
                      width: picked ? 2 : 1),
                ),
                child: Row(children: [
                  PotionIcon(potion: info.id, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name, style: AppText.title(16)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 4, children: [
                          for (final m in info.recipe) MaterialIcon(m, size: 24),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            GoldButton(
              key: const Key('firstPotionMake'),
              label: '만들기',
              height: 44,
              onPressed: !picked || _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final ok = await c.brewFirstPotion();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      if (ok) {
                        firstPotionPicked.value = false;
                        firstPotionMadeTick.value++;
                      } else {
                        showTopNotice(context, '재료가 모자라요.');
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// 다 끓은 물약을 받았을 때 (품질 보여 줌)
Future<void> showBrewResult(BuildContext context, AppController c, BrewResult r) {
  final String title;
  final String line;
  if (r.suspicious != null) {
    title = '수상한 물약';
    line = '맞는 조합이 아니었나 봐요. 무슨 효과일지는 마셔 봐야 알아요.';
  } else {
    final info = AlchemyRules.info(r.potion!);
    // 품질 (11-11 #74): 등급만 보여 주고 판정은 숨긴다
    title = switch (r.quality) {
      PotionQuality.best => '최상 품질!',
      PotionQuality.good => '좋은 품질!',
      PotionQuality.normal => info.name,
    };
    line = '${info.name} ${r.count}개를 만들었어요. 품질: ${r.quality.label}'
        '${r.quality == PotionQuality.normal ? '' : '\n효과가 더 크고 오래가요.'}'
        '${r.discovered ? '\n새 레시피를 레시피 책에 적었어요.' : ''}';
  }
  return showDialog<void>(
    context: context,
    builder: (d) => GameAlert(
      title: Row(children: [
        PotionIcon(
            potion: r.potion, suspicious: r.suspicious != null, size: 40),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: AppText.title(19, color: AppColors.goldBright))),
      ]),
      content: KText(line,
          style: const TextStyle(color: AppColors.text, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요')),
      ],
    ),
  );
}

/// 재료 가공 (11-11 #59): 대장간 · 공방
class ProcessPanel extends StatelessWidget {
  const ProcessPanel({super.key, required this.controller, this.smithy = false});

  final AppController controller;

  /// 대장간 가공(광석·나무·가죽)인지, 공방 가공(젤리·약초·코어)인지
  final bool smithy;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final list = [
      for (final r in ProcessRules.all)
        if (r.smithy == smithy) r,
    ];
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(smithy ? '대장간 가공' : '공방 가공', style: AppText.title(19)),
          const SizedBox(height: 6),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                MaterialIcon(r.output, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Materials.info(r.output).name,
                          style: AppText.title(14, color: AppColors.text)),
                      KText(r.label,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: GoldButton(
                    label: '가공',
                    height: 36,
                    fontSize: 14,
                    onPressed: c.canProcess(r)
                        ? () async {
                            final ok = await c.process(r);
                            if (!context.mounted) return;
                            showTopNotice(context, ok
                                    ? '${josa(Materials.info(r.output).name, '을/를')} 만들었어요.'
                                    : '재료나 금화가 모자라요.');
                          }
                        : null,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// 묶음 75 #318: 오른쪽 위 둥근 「레시피」 버튼
class _RecipeButton extends StatelessWidget {
  const _RecipeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('recipeOpen'),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xE61A1636),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.goldBright, width: 1.4),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 8)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/item_recipe_note.webp',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: AppColors.goldBright, size: 20)),
            const SizedBox(width: 4),
            Text('레시피', style: AppText.title(14, color: AppColors.goldBright)),
          ]),
        ),
      );
}
