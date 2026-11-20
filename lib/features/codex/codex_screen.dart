import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/modifier_view.dart';
import '../bulssi/bulssi_bubble.dart';
import '../pets/pet_art.dart';
import '../battle/element_view.dart';
import '../smithy/equipment_view.dart' show EquipIcon;

/// 도감 (11-11 #41): 탭 없이 몬스터 한 목록. 속성 슬라임도 각각 한 칸.
/// 목록 아래에 「희귀·전설 사냥 기록」. 칭호는 프로필로 옮겼다.
class CodexScreen extends StatefulWidget {
  const CodexScreen({
    super.key,
    required this.purifiedMonsters,
    this.highlandOpen = false,
    this.huntCounts = const {},
    this.modHunts = const {},
    this.monGearFound = const {},
    this.petsSeen = const {},
    this.onOpenPets,
    this.petsOpen = false,
    this.petsNew = false,
    this.onPetsTab,
    this.fresh = const {},
    this.onSeen,
    this.active = true,
  });

  /// 묶음 77 #337: 얻은 적 있는 몬스터 전용 장비 (얻기 전엔 「???」)
  final Set<EquipBase> monGearFound;

  /// 묶음 70 #293: 처음 발견하고 아직 도감에서 보지 않은 칸 ('m:<몬스터>' · 'p:<펫>') — 반짝임 + 점
  final Set<String> fresh;

  /// 도감을 보면 (한 번 보면 반짝임 · 점이 사라짐)
  final VoidCallback? onSeen;

  /// 도감 탭이 보이는 중인지 (보일 때 새 칸을 반짝이고 본 것으로 남김)
  final bool active;

  /// 펫 탭이 열렸는지 (11-11 #96: 첫 알을 받은 뒤부터. 그 전에는 탭을 아예 숨긴다)
  final bool petsOpen;

  /// 펫 탭에 새 표시
  final bool petsNew;

  /// 펫 탭을 처음 열었을 때
  final VoidCallback? onPetsTab;

  /// 한 번이라도 함께한 펫 종류 (11-11 #38 펫 탭)
  final Set<PetSpecies> petsSeen;

  /// 「내 펫」 화면 열기 (정령이 떠나기 전에는 null)
  final VoidCallback? onOpenPets;

  /// 한 번이라도 사냥한 몬스터
  final Set<MonsterId> purifiedMonsters;

  /// 묶음 50 확인 답: 하이랜드 6칸은 Lv.17(하이랜드가 열린 뒤)부터. 만난 칸은 언제나 보인다
  final bool highlandOpen;

  /// 종류별 사냥한 마릿수
  final Map<MonsterId, int> huntCounts;

  /// 희귀·전설 수식어 몬스터 사냥 기록 ([ModifierRules.codexKey] → 마릿수)
  final Map<String, int> modHunts;

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  int _tab = 0;

  /// 이번에 연 동안 반짝일 칸 (열자마자 본 것으로 남김)
  Set<String> _glow = const {};

  void _opened() {
    _glow = {...widget.fresh};
    if (widget.fresh.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onSeen?.call());
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _opened();
  }

  @override
  void didUpdateWidget(CodexScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _opened();
    if (!widget.active && old.active) _glow = const {};
  }

  Set<MonsterId> get purifiedMonsters => widget.purifiedMonsters;
  Map<MonsterId, int> get huntCounts => widget.huntCounts;
  Map<String, int> get modHunts => widget.modHunts;

  Future<void> _showMonster(BuildContext context, MonsterInfo m) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: MonsterPicture(monster: m.id, size: 140)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ElementIcon(m.element, size: 22),
                  const SizedBox(width: 6),
                  Text(m.name,
                      style: AppText.title(22, color: AppColors.goldBright)),
                ]),
                const SizedBox(height: 4),
                Text('${huntCounts[m.id] ?? 0}마리 사냥 · ${m.habitat}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                if (m.description.isNotEmpty)
                  KText(m.description,
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 14)),
                const SizedBox(height: 10),
                _Fact(label: '전투 특징', value: m.traitText),
                _Fact(label: '성향', value: m.tendencyName),
                // 묶음 77 #337: 인간형 몬스터 전용 장비
                if (MonGearRules.gearOf(m.id) case final g?)
                  Padding(
                    key: const Key('codexDrops'),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      const SizedBox(
                        width: 72,
                        child: Text('떨어뜨리는 것',
                            style: TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      if (widget.monGearFound.contains(g)) ...[
                        EquipIcon(base: g, size: 36),
                        const SizedBox(width: 8),
                        Expanded(
                          child: KText(EquipmentRules.info(g).name,
                              key: Key('codexDrop_${g.name}'),
                              style: const TextStyle(color: AppColors.text, fontSize: 14)),
                        ),
                      ] else
                        const Text('???',
                            key: Key('codexDropUnknown'),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(height: 12),
                FrameButton(
                    label: '닫기', onPressed: () => Navigator.of(sheet).pop()),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final tab = widget.petsOpen ? _tab : 0;
    // 묶음 70 #293: 발견한 것만 · 갈래마다 · 「발견 ○종」
    final found = <String, List<MonsterInfo>>{};
    for (final m in Monsters.codex.followedBy([for (final id in MonsterId.values) Monsters.info(id)])) {
      if (!purifiedMonsters.contains(m.id)) continue;
      final g = Monsters.codexGroup(m.id);
      if (g == null) continue;
      final list = found.putIfAbsent(g, () => []);
      if (!list.any((x) => x.id == m.id)) list.add(m);
    }
    final foundCount = found.values.fold<int>(0, (t, l) => t + l.length);
    final records = [
      for (final e in modHunts.entries)
        if (ModifierRules.parseCodexKey(e.key) case (final monster, final mods))
          (monster, mods, e.value),
    ]..sort((a, b) => ModifierRules.gradeOf(b.$2)
        .index
        .compareTo(ModifierRules.gradeOf(a.$2).index));

    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OrnateTopBar(title: '도감'),
          const SizedBox(height: 6),
          SpiritBadgeRow(
              line: tab == 1 && widget.petsOpen
                  ? '함께한 펫은 여기 기록돼. 언젠가 귀한 펫도 만날 거야!'
                  : '사냥한 몬스터는 여기 기록돼. 새로운 몬스터를 찾아보자!'),
          const SizedBox(height: 8),
          // 11-11 #96·#97: 종족은 돋보기 「감정 앨범」으로 옮겼고, 펫 탭은 첫 알 뒤에만
          if (widget.petsOpen)
          Row(children: [
            for (final (i, label) in const [(0, '몬스터'), (1, '펫')]) ...[
              Expanded(
                child: ChoiceChip(
                  key: Key('codexTab_$i'),
                  label: SizedBox(
                      width: double.infinity,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(label, textAlign: TextAlign.center),
                            if (i == 1 && widget.petsNew) ...[
                              const SizedBox(width: 4),
                              Container(
                                key: const Key('codexPetNew'),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.alert,
                                    shape: BoxShape.circle),
                              ),
                            ],
                          ])),
                  selected: tab == i,
                  onSelected: (_) {
                    setState(() => _tab = i);
                    if (i == 1) widget.onPetsTab?.call();
                  },
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.chipBg,
                  labelStyle: TextStyle(
                      color: tab == i ? AppColors.night : AppColors.text,
                      fontWeight: FontWeight.w700),
                  showCheckmark: false,
                ),
              ),
              if (i < 1) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 8),
          if (tab == 1)
            Expanded(
                child: _PetCodex(
                    seen: widget.petsSeen, onOpenPets: widget.onOpenPets, fresh: _glow))
          else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                OrnatePanel(
                  key: const Key('codexMonsters'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('몬스터 도감 · 발견 $foundCount종', key: const Key('codexFound'), style: AppText.title(19)),
                      if (foundCount == 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: KText('아직 만난 몬스터가 없어요. 지도에서 몬스터를 찾아보세요.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                        ),
                      for (final g in Monsters.codexGroups)
                        if (found[g] case final list?) ...[
                          const SizedBox(height: 10),
                          Text('$g · ${list.length}종', key: Key('codexGroup_$g'), style: AppText.title(15, color: AppColors.goldBright)),
                          const SizedBox(height: 6),
                          GridView.count(
                            crossAxisCount: 3,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.72,
                            children: [
                              for (final m in list)
                                _MonsterTile(
                                  key: Key('codexTile_${m.id.name}'),
                                  info: m,
                                  hunted: true,
                                  fresh: _glow.contains('m:${m.id.name}'),
                                  count: huntCounts[m.id] ?? 0,
                                  onTap: () => _showMonster(context, m),
                                ),
                            ],
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('희귀·전설 사냥 기록', style: AppText.title(19)),
                      const SizedBox(height: 8),
                      if (records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: KText(
                              '아직 없어요. 지도에서 파란 이름이나 주황 이름의 몬스터를 찾아보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)),
                        ),
                      for (final (monster, mods, n) in records)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            MonsterPicture(monster: monster, size: 40),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  ModifierRules.displayName(monster, mods),
                                  style: TextStyle(
                                      color: modGradeColor(
                                          ModifierRules.gradeOf(mods)),
                                      fontSize: 14,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: KText(value,
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ),
        ]),
      );
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile(
      {super.key, required this.info, required this.hunted, this.count = 0, this.onTap, this.fresh = false});

  /// 묶음 70 #293: 처음 발견하고 처음 보는 칸 — 반짝임 + 점
  final bool fresh;

  final MonsterInfo info;
  final bool hunted;

  /// 사냥한 마릿수
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = _tileBody();
    if (!fresh) return GestureDetector(onTap: onTap, child: tile);
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: _Sparkle(key: Key('codexFresh_${info.id.name}'))),
        tile,
        const Positioned(right: 4, top: 4, child: _NewDot()),
      ]),
    );
  }

  Widget _tileBody() {
    return GestureDetector(
      onTap: null,
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
                  ? Stack(children: [
                      Positioned.fill(
                          child: MonsterPicture(monster: info.id, size: 88)),
                      Positioned(
                          top: 0, left: 0, child: ElementIcon(info.element, size: 16)),
                    ])
                  : ColorFiltered(
                      // 아직 사냥하지 않은 몬스터는 그림자로만 보인다
                      colorFilter: const ColorFilter.mode(
                          AppColors.abyss, BlendMode.srcATop),
                      child: MonsterPicture(monster: info.id, size: 88),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              hunted ? '${info.name}\n$count마리' : '???',
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

/// 칭호 아이콘 (그림이 오기 전에는 이 아이콘으로)
IconData titleIcon(TitleId id) => switch (id) {
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
      // 속성 칭호 (11-11 #63)
      _ => Icons.auto_awesome_motion_rounded,
    };

/// 도감 펫 탭: 일반 6종 (희귀·전설은 나중에 더한다)
class _PetCodex extends StatelessWidget {
  const _PetCodex({required this.seen, this.onOpenPets, this.fresh = const {}});

  final Set<PetSpecies> seen;
  final Set<String> fresh;
  final VoidCallback? onOpenPets;

  Future<void> _show(BuildContext context, PetSpeciesInfo info) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  PetArt(species: info.id, size: 100),
                  const SizedBox(width: 12),
                  PetArt(species: info.id, adult: true, size: 120),
                ]),
                const SizedBox(height: 8),
                Text('${info.name}${petGradeTag(info.grade)}',
                    textAlign: TextAlign.center,
                    style: AppText.title(22, color: AppColors.goldBright)),
                const SizedBox(height: 10),
                // 묶음 32 #184: 숫자 없이 문장으로, 성체는 한 줄로
                _Fact(label: '원정 특기', value: info.special),
                // 묶음 49 #235: 영웅 펫 함께 걸을 때
                if (info.walk != null) _Fact(label: '함께 걸을 때', value: info.walk!),
                _Fact(
                    label: '던전 스킬',
                    value: '${info.skillName} · ${info.skillText}'),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('자라면 더 좋아져요',
                      key: Key('petGrowsBetter'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
                const SizedBox(height: 12),
                FrameButton(
                    label: '닫기', onPressed: () => Navigator.of(sheet).pop()),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 묶음 70 #293: 한 번이라도 가졌던 펫만 · 등급 갈래마다 · 「발견 ○종」
              Text('펫 도감 · 발견 ${seen.length}종', key: const Key('petCodexFound'), style: AppText.title(19)),
              for (final g in PetGrade.values)
                if ([for (final s in PetSpecies.values) if (seen.contains(s) && PetRules.info(s).grade == g) s] case final list when list.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                      '${switch (g) {
                        PetGrade.common => '일반',
                        PetGrade.rare => '희귀',
                        PetGrade.hero => '영웅',
                        PetGrade.legend => '전설',
                      }} · ${list.length}종',
                      key: Key('petGroup_${g.name}'),
                      style: AppText.title(15, color: AppColors.goldBright)),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 3,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                    children: [
                      for (final s in list)
                        GestureDetector(
                          key: Key('petTile_${s.name}'),
                          onTap: () => _show(context, PetRules.info(s)),
                          child: Stack(clipBehavior: Clip.none, children: [
                            if (fresh.contains('p:${s.name}')) const Positioned.fill(child: _Sparkle()),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B1E4C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.goldBright),
                              ),
                              child: Column(children: [
                                Expanded(child: PetArt(species: s, size: 80)),
                                Text(PetRules.info(s).name,
                                    style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                            if (fresh.contains('p:${s.name}')) const Positioned(right: 4, top: 4, child: _NewDot()),
                          ]),
                        ),
                    ],
                  ),
                ],
              if (seen.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: KText('아직 함께한 펫이 없어요.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ),
            ],
          ),
        ),
        if (onOpenPets != null) ...[
          const SizedBox(height: 10),
          FrameButton(label: '내 펫 보기', onPressed: onOpenPets),
        ],
      ],
    );
  }
}


/// 묶음 70 #293: 처음 발견한 칸의 반짝임 (한 번 보면 사라짐)
class _Sparkle extends StatefulWidget {
  const _Sparkle({super.key});

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle> with SingleTickerProviderStateMixin {
  // 몇 번 반짝인 뒤 은은하게 멈춤 (점은 그대로)
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true, count: 6);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: AppColors.goldBright.withValues(alpha: 0.35 + 0.45 * _a.value), blurRadius: 10 + 10 * _a.value, spreadRadius: 1),
            ],
          ),
        ),
      );
}

class _NewDot extends StatelessWidget {
  const _NewDot();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('codexNew'),
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}
