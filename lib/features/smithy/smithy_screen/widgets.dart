part of '../smithy_screen.dart';

Widget _ic(String name) => GameIcon(name,
    size: 16,
    fallback: name == 'gold'
        ? Icons.monetization_on_rounded
        : Icons.diamond_rounded);

/// 탭 바로 위 오른쪽 작은 한 줄 (마석 · 금화)
class _WalletLine extends StatelessWidget {
  const _WalletLine({required this.manaStones, required this.gold});

  final int manaStones;
  final int gold;

  @override
  Widget build(BuildContext context) {
    Widget one(String icon, IconData fb, int n, Key key) => Row(
          key: key,
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 18, fallback: fb),
            const SizedBox(width: 3),
            Text(comma(n),
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        );
    return Row(
      key: const Key('smithyWallet'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        one('mana_stone', Icons.diamond_rounded, manaStones,
            const Key('wallet_mana')),
        const SizedBox(width: 12),
        one('gold', Icons.monetization_on_rounded, gold,
            const Key('wallet_gold')),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? kGoldGradient : null,
            color: selected ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: TextStyle(
                    color: selected ? AppColors.goldInk : AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
      );
}

class _SlotChip extends StatelessWidget {
  const _SlotChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0x55F2C14E) : const Color(0x8812153A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? AppColors.goldBright
                    : AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.goldBright : AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 6),
        child: Text(text,
            style: AppText.title(15, color: AppColors.goldBright)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
}

/// 모자란 것 한 줄: 아이콘 + 「마석 1개 모자라요」
class _Short extends StatelessWidget {
  const _Short({required this.lines});

  /// (아이콘, 「마석 1개」)
  final List<(Widget, String)> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        SizedBox(width: 16, height: 16, child: lines.first.$1),
        const SizedBox(width: 4),
        Expanded(
          child: KText('${lines.map((l) => l.$2).join(' · ')} 모자라요',
              style: const TextStyle(
                  color: Color(0xFFE5A0A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// 드는 재료 칸 (모자란 칸은 빨갛게)
class _NeedWrap extends StatelessWidget {
  const _NeedWrap({required this.info, required this.controller, this.rare});

  final EquipBaseInfo info;
  final AppController controller;
  final MaterialId? rare;

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    Widget need(Widget icon, String name, int have, int n) => Container(
          padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: have >= n ? const Color(0x66101333) : const Color(0x55E57373),
            border: Border.all(
                color: have >= n
                    ? const Color(0x997BE08A)
                    : const Color(0xFFE57373)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 3),
            Text('$name $have/$n',
                style: TextStyle(
                    color: have >= n ? AppColors.text : const Color(0xFFFFB4B4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        );
    final recipe = {...info.recipe};
    if (rare != null) recipe[rare!] = (recipe[rare!] ?? 0) + 1;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in recipe.entries)
        need(MaterialIcon(e.key, size: 18), Materials.needName(e.key),
            p.materialCount(e.key), e.value),
      if (info.manaStones > 0)
        need(
            const GameIcon('mana_stone',
                size: 18, fallback: Icons.diamond_rounded),
            '마석',
            p.manaStones,
            info.manaStones),
    ]);
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.info,
    required this.controller,
    required this.ready,
    required this.onCraft,
  });

  final EquipBaseInfo info;
  final AppController controller;
  final bool ready;
  final VoidCallback onCraft;

  /// 모자란 재료 한 줄 「박쥐 날개 1개 모자라요」
  String _missing() {
    final p = controller.player;
    final parts = [
      for (final e in info.recipe.entries)
        if (p.materialCount(e.key) < e.value)
          '${Materials.needName(e.key)} ${e.value - p.materialCount(e.key)}개',
      if (p.manaStones < info.manaStones)
        '마석 ${info.manaStones - p.manaStones}개',
    ];
    return '${parts.join(' · ')} 모자라요';
  }

  @override
  Widget build(BuildContext context) {
    final check = controller.canCraft(info.id);
    final worn = controller.armory.wornIn(info.slot);
    const up = Color(0xFF7BE08A);
    Widget compare;
    if (!ready) {
      compare = KText(_missing(),
          key: Key('missing_${info.id.name}'),
          style: const TextStyle(
              color: Color(0xFFFFB4B4),
              fontSize: 12.5,
              fontWeight: FontWeight.w700));
    } else if (worn == null) {
      compare = const Text('새 부위',
          style: TextStyle(
              color: Color(0xFF7FB8FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w800));
    } else {
      final lines = EquipmentRules.compareWith(info.id, worn);
      compare = lines.isEmpty
          ? const Text('지금 입은 것과 같아요',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
          : Wrap(spacing: 10, runSpacing: 2, children: [
              for (final (good, text) in lines)
                Text('${good ? '▲' : '▼'} $text',
                    style: TextStyle(
                        color: good ? up : AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
            ]);
    }
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          EquipIcon(base: info.id, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(info.name,
                          style: AppText.title(16, color: AppColors.text)),
                      if (ready)
                        Container(
                          key: Key('canMake_${info.id.name}'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0x337BE08A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x997BE08A)),
                          ),
                          child: const Text('만들 수 있어요',
                              style: TextStyle(
                                  color: up,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ]),
                Text(
                    // 묶음 26 #178: 어울리는 직업은 직업이 생긴 뒤에 (지금은 숨김)
                    '${EquipmentRules.slotLabel(info.slot)} · ${info.statLabel}'
                    '${info.job == null || !LockedJobPanel.jobsVisible ? '' : ' · 어울리는 직업 ${info.job}'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        compare,
        const SizedBox(height: 8),
        _NeedWrap(info: info, controller: controller),
        const SizedBox(height: 8),
        Row(children: [
          if (check == CraftCheck.bagFull)
            const Expanded(
              child: KText('가방이 가득 찼어요. 가방을 비우거나 늘려 주세요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            const Spacer(),
          SizedBox(
            width: 120,
            child: GoldButton(
              key: Key('craft_${info.id.name}'),
              label: '만들기',
              height: 40,
              fontSize: 14,
              onPressed: check == CraftCheck.ok ? onCraft : null,
            ),
          ),
        ]),
      ],
    );
    return OrnatePanel(
      key: Key('recipe_${info.id.name}'),
      child: ready ? body : Opacity(opacity: 0.72, child: body),
    );
  }
}

/// 가진 장비 카드 (강화·수리·속성 탭). 입는 중이면 금테를 굵게
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.worn,
    required this.bottom,
    this.showDurability = false,
    this.menu,
    this.trailing,
  });

  final EquipItem item;
  final bool worn;
  final Widget bottom;
  final bool showDurability;
  final Widget? menu;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final card = OrnatePanel(
      highlight: worn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            EquipIcon(base: item.base, grade: item.grade, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: EquipName(item, size: 16)),
                    if (worn) ...[
                      const SizedBox(width: 6),
                      const Text('입는 중',
                          style: TextStyle(
                              color: AppColors.goldBright, fontSize: 12)),
                    ],
                  ]),
                  ItemStats(item, fontSize: 12),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            if (menu != null) menu!,
          ]),
          if (showDurability) ...[
            const SizedBox(height: 6),
            DurabilityBar(value: item.durability),
          ],
          const SizedBox(height: 6),
          bottom,
        ],
      ),
    );
    if (!worn) return card;
    // 입는 중: 금테를 굵게
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBright, width: 2.4),
        boxShadow: const [
          BoxShadow(color: Color(0x55F2C14E), blurRadius: 8),
        ],
      ),
      child: card,
    );
  }
}

/// 카드 오른쪽 위 ⋯ : 「분해하기」
class _SalvageMenu extends StatelessWidget {
  const _SalvageMenu(
      {required this.uid, required this.worn, required this.onSalvage});

  final String uid;
  final bool worn;
  final VoidCallback onSalvage;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: PopupMenuButton<int>(
          key: Key('more_$uid'),
          padding: EdgeInsets.zero,
          color: AppColors.night,
          icon: const Icon(Icons.more_horiz_rounded,
              color: AppColors.goldBright),
          onSelected: (_) => onSalvage(),
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              key: Key('salvage_$uid'),
              value: 0,
              enabled: !worn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('분해하기',
                      style: TextStyle(
                          color: worn
                              ? AppColors.textMuted
                              : AppColors.danger,
                          fontWeight: FontWeight.w800)),
                  Text(
                      worn ? '입는 중이에요' : '마석과 재료 일부를 돌려받아요',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 속성 탭 버튼 (금빛 · 보통). 비용은 작게
class _CostButton extends StatelessWidget {
  const _CostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.cost,
    this.gold = false,
  });

  final String label;
  final String? cost;
  final bool gold;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    final ink = gold && on ? AppColors.goldInk : AppColors.text;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: on ? 1 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            gradient: gold && on ? kGoldGradient : null,
            color: gold && on ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            KText(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
            if (cost != null)
              KText(cost!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// 속성 고르기 한 칸 (코어가 있는 속성만 밝게)
class _ElementCell extends StatelessWidget {
  const _ElementCell({
    super.key,
    required this.element,
    required this.width,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final Element element;
  final double width;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: owned ? 1 : 0.4,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0x55F2C14E) : const Color(0x6612153A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? AppColors.goldBright
                      : AppColors.gold.withValues(alpha: 0.35),
                  width: selected ? 2 : 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ElementIcon(element, size: 24),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(element.label,
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}

/// 첫 채집 도구 (Lv.5, 무료)
class _FirstToolPanel extends StatelessWidget {
  const _FirstToolPanel({required this.onMake});

  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('첫 채집 도구', style: AppText.title(17)),
            const SizedBox(height: 4),
            const KText('낫·곡괭이·도끼·낚싯대·붓을 한 벌 만들어요. 처음 한 번은 무료예요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            GoldButton(
              key: const Key('firstToolMake'),
              label: '만들기 (무료)',
              height: 46,
              fontSize: 16,
              onPressed: onMake,
            ),
          ],
        ),
      );
}
