import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/element_view.dart' show elementColor;
import '../bulssi/bulssi_bubble.dart';
import '../town/material_view.dart';
import '../harvest/harvest_sheet.dart' show ToolRepairPanel;
import 'convert_panel.dart';

/// 연금술 공방 (11-11 #57·#58): 가마솥 · 레시피 책 · 재료 가공
class AlchemyScreen extends StatefulWidget {
  const AlchemyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AlchemyScreen> createState() => _AlchemyScreenState();
}

class _AlchemyScreenState extends State<AlchemyScreen> {
  int _tab = 0;
  static const _tabs = ['가마솥', '레시피', '가공', '변환'];

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => ListView(
            padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
            children: [
              OrnateTopBar(
                  title: '연금술 공방',
                  onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 6),
              BulssiLine(
                  line: switch (_tab) {
                0 => '넣는 순서가 딱 맞거나 귀한 재료를 쓰면 품질이 좋아져!',
                1 => '한 번 만든 물약은 여기 적혀. 쪽지를 읽으면 재료를 알 수 있어.',
                2 => '하위 재료 여러 개를 상위 재료로 바꿀 수 있어.',
                _ => '남는 재료를 바꾸거나, 마석을 속성 마석으로 정제할 수 있어.',
              }),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < _tabs.length; i++) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: SizedBox(
                          width: double.infinity,
                          child: Text(_tabs[i], textAlign: TextAlign.center)),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                      selectedColor: AppColors.gold,
                      backgroundColor: const Color(0xFF1E2250),
                      labelStyle: TextStyle(
                          color: _tab == i ? AppColors.night : AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      showCheckmark: false,
                    ),
                  ),
                  if (i < _tabs.length - 1) const SizedBox(width: 6),
                ],
              ]),
              const SizedBox(height: 10),
              ...switch (_tab) {
                0 => _cauldrons(context),
                1 => _book(context),
                3 => [ConvertPanel(controller: c)],
                _ => [
                    ProcessPanel(controller: c),
                    const SizedBox(height: 10),
                    ToolRepairPanel(controller: c, smithy: false),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── 가마솥

  List<Widget> _cauldrons(BuildContext context) {
    final a = c.alchemy;
    final gold = c.cauldronGold;
    return [
      for (var i = 0; i < a.cauldrons; i++) ...[
        _CauldronCard(controller: c, slot: i),
        const SizedBox(height: 10),
      ],
      if (gold != null) ...[
        FrameButton(
          label: '가마솥 하나 더 · 금화 ${comma(gold)}'
              '${c.cauldronStone > 0 ? ' + 미궁 석재 ${c.cauldronStone}' : ''}',
          gameIcon: 'gold',
          height: 44,
          onPressed: () async {
            final ok = await c.buyCauldron();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? '가마솥이 하나 늘었어요!' : '금화나 재료가 모자라요.')));
          },
        ),
        const SizedBox(height: 10),
      ],
      AlchemistPanel(controller: c),
    ];
  }

  // ───────────── 레시피 책

  List<Widget> _book(BuildContext context) {
    final known = c.knownRecipes;
    return [
      if (c.recipeNotes > 0)
        Center(
          child: Image.asset('assets/images/item_recipe_note.png',
              height: 64,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      if (c.recipeNotes > 0)
        GoldButton(
          label: '레시피 쪽지 읽기 (${c.recipeNotes}장)',
          height: 46,
          onPressed: () async {
            final id = await c.readNote();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(id == null
                    ? '더 알아낼 레시피가 없어요.'
                    : '「${AlchemyRules.info(id).name}」의 재료를 알아냈어요!')));
          },
        ),
      if (c.recipeNotes > 0) const SizedBox(height: 10),
      OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Image.asset('assets/images/item_recipe_book.png',
                  width: 40,
                  height: 40,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.goldBright)),
              const SizedBox(width: 8),
              Text('알아낸 레시피 ${known.length}', style: AppText.title(18)),
            ]),
            const SizedBox(height: 2),
            const KText('모르는 물약은 이름도 보이지 않아요. 재료를 자유롭게 넣어 끓여 보세요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            for (final id in known) _RecipeRow(controller: c, id: id),
          ],
        ),
      ),
    ];
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.controller, required this.id});

  final AppController controller;
  final PotionId id;

  @override
  Widget build(BuildContext context) {
    final info = AlchemyRules.info(id);
    final made = controller.recipeDiscovered(id);
    // 넣는 순서는 알려 주지 않는다: 재료 순서로 정렬해서 보여 준다
    final counts = info.counts.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        PotionIcon(potion: id, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${info.name}${made ? '' : ' (쪽지)'}',
                  style: AppText.title(15, color: AppColors.text)),
              KText(
                  '${[for (final e in counts) '${Materials.info(e.key).name} ${e.value}'].join(' · ')}'
                  ' · ${info.minutes}분 · ${info.yields}개',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ]),
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
        PotionKind.heal => const Color(0xFFE57373),
        PotionKind.mana => const Color(0xFF5FA8F0),
        PotionKind.care => const Color(0xFF7FD0A0),
        PotionKind.buff => const Color(0xFFF0A93B),
        PotionKind.resist => const Color(0xFFC79BFF),
        PotionKind.special => AppColors.goldBright,
        PotionKind.weapon => elementColor(AlchemyRules.info(p!).element),
        null => const Color(0xFF9AA6D8),
      };

  @override
  Widget build(BuildContext context) {
    final asset = suspicious || potion == null
        ? 'assets/images/potion_suspicious.png'
        : AlchemyRules.info(potion!).asset;
    return Image.asset(asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
            suspicious ? Icons.help_center_rounded : Icons.science_rounded,
            size: size * 0.8,
            color: colorOf(suspicious ? null : potion)));
  }
}

class _CauldronCard extends StatelessWidget {
  const _CauldronCard({required this.controller, required this.slot});

  final AppController controller;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final brew = c.alchemy.brews[slot];
    final ready = c.brewReady(slot);
    Widget body;
    if (brew == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KText('비어 있어요. 재료를 최대 5개까지 순서대로 넣어 끓여요.',
              style: TextStyle(color: AppColors.text, fontSize: 13)),
          const SizedBox(height: 8),
          GoldButton(
            label: '재료 넣기',
            height: 44,
            onPressed: () => showBrewSheet(context, c, slot),
          ),
        ],
      );
    } else {
      final total = brew.readyAt.difference(brew.startedAt).inSeconds;
      final done = c.now.difference(brew.startedAt).inSeconds;
      final left = brew.readyAt.difference(c.now);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final n in brew.put)
              if (Materials.byName(n) case final m?) MaterialIcon(m, size: 28),
          ]),
          const SizedBox(height: 6),
          GlowBar(
              ratio: total <= 0 ? 1 : (done / total).clamp(0.0, 1.0),
              colors: BarColors.exp,
              height: 7),
          const SizedBox(height: 4),
          Text(
              ready
                  ? '다 끓었어요!'
                  : '${left.inMinutes >= 60 ? '${left.inHours}시간 ${left.inMinutes % 60}분' : '${left.inMinutes + 1}분'} 남았어요',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          if (ready) ...[
            const SizedBox(height: 8),
            GoldButton(
              label: '꺼내기',
              height: 44,
              onPressed: () async {
                final r = await c.collectBrew(slot);
                if (r == null || !context.mounted) return;
                await _showResult(context, c, r);
              },
            ),
          ],
        ],
      );
    }
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Image.asset('assets/images/cauldron.png',
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => const Icon(Icons.soup_kitchen_rounded,
                    size: 36, color: AppColors.goldBright)),
            const SizedBox(width: 8),
            Text('가마솥 ${slot + 1}', style: AppText.title(17)),
          ]),
          const SizedBox(height: 8),
          body,
        ],
      ),
    );
  }
}

Future<void> _showResult(BuildContext context, AppController c, BrewResult r) {
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

/// 가마솥에 재료 넣기: 누른 순서대로 쌓이고, 다시 누르면 빠진다
Future<void> showBrewSheet(BuildContext context, AppController c, int slot) {
  final put = <MaterialId>[];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setState) {
        final have = c.player.materials;
        int left(MaterialId m) =>
            (have[m] ?? 0) - put.where((x) => x == m).length;
        final mats = have.keys.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('가마솥 ${slot + 1}에 넣기', style: AppText.title(19)),
                  const SizedBox(height: 6),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161A44),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(children: [
                      for (var i = 0; i < AlchemyRules.maxIngredients; i++) ...[
                        Expanded(
                          child: i < put.length
                              ? GestureDetector(
                                  onTap: () => setState(() => put.removeAt(i)),
                                  child: MaterialIcon(put[i], size: 38))
                              : Icon(Icons.add_circle_outline_rounded,
                                  color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        if (i < AlchemyRules.maxIngredients - 1)
                          Icon(Icons.chevron_right_rounded,
                              size: 14,
                              color: AppColors.gold.withValues(alpha: 0.4)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const KText('넣은 재료를 누르면 빠져요. 왼쪽부터 넣은 순서예요.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: mats.isEmpty
                        ? const KText('가방에 재료가 없어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted))
                        : GridView.count(
                            crossAxisCount: 5,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            children: [
                              for (final m in mats)
                                GestureDetector(
                                  onTap: left(m) > 0 &&
                                          put.length < AlchemyRules.maxIngredients
                                      ? () => setState(() => put.add(m))
                                      : null,
                                  child: Opacity(
                                    opacity: left(m) > 0 ? 1 : 0.35,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF161A44),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: AppColors.gold
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: Stack(children: [
                                        Center(child: MaterialIcon(m, size: 36)),
                                        Positioned(
                                          right: 4,
                                          bottom: 2,
                                          child: Text('${left(m)}',
                                              style: const TextStyle(
                                                  color: AppColors.text,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  shadows: [Shadow(blurRadius: 3)])),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),
                  GoldButton(
                    label: '끓이기',
                    height: 46,
                    onPressed: put.isEmpty
                        ? null
                        : () async {
                            final ok = await c.startBrew(slot, put);
                            if (sheet.mounted) Navigator.of(sheet).pop();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('끓이지 못했어요.')));
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          Text(smithy ? '대장간 가공' : '공방 가공', style: AppText.title(18)),
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
                          style: AppText.title(15, color: AppColors.text)),
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
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ok
                                    ? '${josa(Materials.info(r.output).name, '을/를')} 만들었어요.'
                                    : '재료나 금화가 모자라요.')));
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
