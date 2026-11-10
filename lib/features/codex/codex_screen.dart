import 'package:flutter/material.dart';

import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/modifier_view.dart';
import '../bulssi/bulssi_bubble.dart';

/// 도감: 위쪽 「칭호 | 몬스터」 탭으로 그룹을 바꿔 본다 (11-10 E1).
/// 그룹이 늘면 [_CodexScreenState._groups] 에 하나 더하면 된다.
class CodexScreen extends StatefulWidget {
  const CodexScreen({
    super.key,
    required this.player,
    required this.purifiedMonsters,
    this.huntCounts = const {},
    this.modHunts = const {},
    this.equipped,
    this.onEquip,
  });

  final PlayerState player;

  /// 한 번이라도 사냥한 몬스터
  final Set<MonsterId> purifiedMonsters;

  /// 종류별 사냥한 마릿수
  final Map<MonsterId, int> huntCounts;

  /// 희귀·전설 수식어 몬스터 사냥 기록 ([ModifierRules.codexKey] → 마릿수)
  final Map<String, int> modHunts;

  /// 지금 대표 칭호
  final TitleId? equipped;

  /// 얻은 칭호 카드를 눌러 대표 칭호로 걸 때
  final Future<bool> Function(TitleId id)? onEquip;

  static IconData titleIcon(TitleId id) => switch (id) {
        TitleId.firstSteps => Icons.hiking_rounded,
        TitleId.persistentTraveler => Icons.flag_rounded,
        TitleId.morningSpiritFriend => Icons.wb_twilight_rounded,
        TitleId.bookwormSage => Icons.menu_book_rounded,
        TitleId.forcedMarchKnight => Icons.shield_rounded,
        TitleId.nightWalker => Icons.nightlight_round,
        TitleId.awakened => Icons.auto_awesome_rounded,
        TitleId.lanternKeeper => Icons.emoji_objects_rounded,
        TitleId.gateKeeper => Icons.door_back_door_rounded,
        TitleId.lakeFriend => Icons.water_drop_rounded,
        TitleId.townLight => Icons.light_mode_rounded,
      };

  Future<void> _showTitle(
      BuildContext context, TitleInfo t, bool earned) async {
    final isEquipped = t.id == equipped;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                child: Image.asset('assets/images/title_${t.id.name}.png',
                    color: earned ? null : const Color(0xFF2A2D55),
                    colorBlendMode: earned ? null : BlendMode.srcATop,
                    errorBuilder: (_, __, ___) => Icon(titleIcon(t.id),
                        size: 64, color: AppColors.goldBright)),
              ),
              const SizedBox(height: 8),
              Text(earned ? t.name : '???',
                  style: AppText.title(22, color: AppColors.goldBright)),
              const SizedBox(height: 4),
              Text(earned ? '얻은 칭호 · ${t.hint}' : '얻는 방법: ${t.hint}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              if (earned && onEquip != null)
                GoldButton(
                  label: isEquipped ? '지금 대표 칭호예요' : '대표 칭호로 걸기',
                  onPressed: isEquipped
                      ? null
                      : () async {
                          await onEquip!(t.id);
                          if (sheet.mounted) Navigator.of(sheet).pop();
                        },
                )
              else
                FrameButton(
                  label: '닫기',
                  onPressed: () => Navigator.of(sheet).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

/// 도감 그룹 하나 (탭 이름, 모은 수 / 전체, 내용)
class _CodexGroup {
  const _CodexGroup(this.label, this.have, this.total, this.line, this.build);

  final String label;
  final int have;
  final int total;

  /// 이 탭에서 정령이 할 한 줄
  final String line;
  final Widget Function(BuildContext) build;
}

class _CodexScreenState extends State<CodexScreen> {
  int _tab = 0;

  List<_CodexGroup> get _groups => [
        _CodexGroup('칭호', widget.player.titles.length, TitleRules.all.length,
            '숨은 칭호를 같이 찾아보자!', _titles),
        _CodexGroup(
            '몬스터',
            widget.purifiedMonsters.length,
            Monsters.all.length,
            '사냥한 몬스터는 여기 기록돼. ${Monsters.all.length}종 모두 만나 보자!',
            _monsters),
        _CodexGroup(
            '수식어',
            _foundMods.length,
            _rareMods.length,
            '희귀·전설 수식어가 붙은 몬스터는 여기 따로 남아. 파란 이름, 주황 이름을 찾아보자!',
            _modifiers),
      ];

  /// 도감에 남는 수식어 (희귀·전설)
  static List<ModifierInfo> get _rareMods => [
        for (final m in ModifierRules.all)
          if (m.grade.index >= ModGrade.rare.index) m,
      ];

  /// 사냥해서 찾은 희귀·전설 수식어
  Set<ModifierId> get _foundMods => {
        for (final k in widget.modHunts.keys)
          if (ModifierRules.parseCodexKey(k) case (_, final mods))
            for (final m in mods)
              if (ModifierRules.info(m).grade.index >= ModGrade.rare.index) m,
      };

  Widget _modifiers(BuildContext context) {
    final found = _foundMods;
    final entries = [
      for (final e in widget.modHunts.entries)
        if (ModifierRules.parseCodexKey(e.key) case (final monster, final mods))
          (monster, mods, e.value),
    ]..sort((a, b) => ModifierRules.gradeOf(b.$2)
        .index
        .compareTo(ModifierRules.gradeOf(a.$2).index));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('잡은 수식어 몬스터', style: AppText.title(18)),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: KText('아직 없어요. 지도에서 파란 이름이나 주황 이름의 몬스터를 찾아보세요.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              for (final (monster, mods, n) in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    MonsterPicture(monster: monster, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(ModifierRules.displayName(monster, mods),
                          style: TextStyle(
                              color: modGradeColor(ModifierRules.gradeOf(mods)),
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ),
                    Text('$n마리',
                        style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KText('수식어 ${found.length} / ${_rareMods.length}',
                  style: AppText.title(18)),
              const SizedBox(height: 6),
              for (final m in _rareMods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 92,
                      child: Text(found.contains(m.id) ? m.name : '???',
                          style: TextStyle(
                              color: found.contains(m.id)
                                  ? modGradeColor(m.grade)
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(
                          found.contains(m.id)
                              ? m.behavior
                              : '${ModifierRules.gradeLabel(m.grade)} 수식어'
                                  '${m.monster == null ? '' : ' · ${Monsters.info(m.monster!).name} 전용'}',
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 12.5)),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _titles(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.08,
        children: [
          for (final t in TitleRules.all)
            _TitleCard(
              info: t,
              icon: CodexScreen.titleIcon(t.id),
              earned: widget.player.titles.contains(t.id),
              equipped: t.id == widget.equipped,
              onTap: () => widget._showTitle(
                  context, t, widget.player.titles.contains(t.id)),
            ),
        ],
      );

  Widget _monsters(BuildContext context) => OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText(
                '몬스터 도감 ${widget.purifiedMonsters.length} / '
                '${Monsters.all.length}',
                style: AppText.title(18)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
              children: [
                for (final m in Monsters.all)
                  _MonsterTile(
                      info: m,
                      hunted: widget.purifiedMonsters.contains(m.id),
                      count: widget.huntCounts[m.id] ?? 0),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final groups = _groups;
    final g = groups[_tab.clamp(0, groups.length - 1)];

    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrnateTopBar(title: '도감'),
          const SizedBox(height: 6),
          BulssiLine(line: g.line),
          const SizedBox(height: 10),
          _CodexTabs(
            labels: [for (final x in groups) '${x.label} ${x.have}/${x.total}'],
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              key: PageStorageKey('codex_${g.label}'),
              padding: const EdgeInsets.only(bottom: 24),
              children: [g.build(context)],
            ),
          ),
        ],
      ),
    );
  }
}

/// 도감 그룹 탭 (칭호 | 몬스터 …)
class _CodexTabs extends StatelessWidget {
  const _CodexTabs(
      {required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xCC12153A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: i == index
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFB98330), Color(0xFF6E4B1A)],
                          ),
                          border: Border.all(color: AppColors.goldBright),
                        )
                      : null,
                  child: Text(labels[i],
                      style: TextStyle(
                          color: i == index
                              ? const Color(0xFFFFF3C8)
                              : AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.info,
    required this.icon,
    required this.earned,
    required this.equipped,
    this.onTap,
  });

  final TitleInfo info;
  final IconData icon;
  final bool earned;
  final bool equipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picture = ColorFiltered(
      // 얻지 못한 칭호는 어둡게
      colorFilter: earned
          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
          : const ColorFilter.matrix([
              0.12, 0.12, 0.12, 0, 0,
              0.12, 0.12, 0.14, 0, 0,
              0.16, 0.16, 0.22, 0, 0,
              0, 0, 0, 1, 0,
            ]),
      child: Image.asset(
        'assets/images/title_${info.id.name}.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(icon,
            size: 40,
            color: earned ? AppColors.goldBright : AppColors.textMuted),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: OrnatePanel(
            highlight: equipped,
            radius: 14,
            padding: EdgeInsets.zero,
            child: const SizedBox.expand(),
          ),
        ),
        // 트로피 그림: 카드 위쪽에 크게, 이름 리본은 그림 아래에 겹친다
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final ribbonW = w * 0.86;
            final ribbonH = ribbonW / (488 / 176);
            return Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: c.maxHeight * 0.07,
                left: w * 0.14,
                right: w * 0.14,
                bottom: earned ? ribbonH * 0.62 : ribbonH * 0.62 + 22,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: picture),
                  if (!earned)
                    const Icon(Icons.lock_rounded,
                        size: 30, color: AppColors.goldBright),
                ]),
              ),
              Positioned(
                bottom: earned ? 6 : 24,
                width: ribbonW,
                height: ribbonH,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(
                    child: ColorFiltered(
                      colorFilter: earned
                          ? const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix([
                              0.45, 0.2, 0.1, 0, 0,
                              0.4, 0.2, 0.1, 0, 0,
                              0.35, 0.2, 0.2, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                      child: Image.asset('assets/images/ui_ribbon.png',
                          fit: BoxFit.fill,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        ribbonW * 0.16, 0, ribbonW * 0.16, ribbonH * 0.22),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(earned ? info.name : '???',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Title',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: earned
                                ? const Color(0xFF3A2208)
                                : const Color(0xFFE8DCC0),
                          )),
                    ),
                  ),
                ]),
              ),
              if (!earned)
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Text('✦ ${info.hint} ✦',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10)),
                ),
              if (equipped)
                Positioned(
                  top: 6,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(
                      gradient: kGoldGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('장착',
                        style: TextStyle(
                            color: Color(0xFF3A2208),
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ]);
          }),
        ),
      ],
    ),
    );
  }
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile(
      {required this.info, required this.hunted, this.count = 0});

  final MonsterInfo info;
  final bool hunted;

  /// 사냥한 마릿수
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: info.habitat,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: hunted
                ? const [Color(0xFF3A2E6E), Color(0xFF1B1E4C)]
                : const [Color(0xFF1E2152), Color(0xFF14173E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hunted
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Expanded(
              child: hunted
                  ? MonsterPicture(monster: info.id, size: 88)
                  : ColorFiltered(
                      // 아직 사냥하지 않은 몬스터는 그림자로만 보인다
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF0B0D26), BlendMode.srcATop),
                      child: MonsterPicture(monster: info.id, size: 88),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              hunted ? '${info.name}\n${count}마리' : '???',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: hunted ? AppColors.text : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
