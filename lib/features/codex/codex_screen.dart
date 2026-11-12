import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/modifier_view.dart';
import '../bulssi/bulssi_bubble.dart';
import '../pets/pet_art.dart';
import '../battle/element_view.dart';

/// 도감 (11-11 #41): 탭 없이 몬스터 한 목록. 속성 슬라임도 각각 한 칸.
/// 목록 아래에 「희귀·전설 사냥 기록」. 칭호는 프로필로 옮겼다.
class CodexScreen extends StatefulWidget {
  const CodexScreen({
    super.key,
    required this.purifiedMonsters,
    this.huntCounts = const {},
    this.modHunts = const {},
    this.petsSeen = const {},
    this.onOpenPets,
    this.petsOpen = false,
    this.petsNew = false,
    this.onPetsTab,
  });

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

  /// 종류별 사냥한 마릿수
  final Map<MonsterId, int> huntCounts;

  /// 희귀·전설 수식어 몬스터 사냥 기록 ([ModifierRules.codexKey] → 마릿수)
  final Map<String, int> modHunts;

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends State<CodexScreen> {
  int _tab = 0;

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
                        color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 12),
                if (m.description.isNotEmpty)
                  KText(m.description,
                      style:
                          const TextStyle(color: AppColors.text, fontSize: 14)),
                const SizedBox(height: 10),
                _Fact(label: '전투 특징', value: m.traitText),
                _Fact(label: '성향', value: m.tendencyName),
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
    final all = Monsters.all;
    final have = [for (final m in all) if (purifiedMonsters.contains(m.id)) m];
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
          BulssiLine(
              line: tab == 1 && widget.petsOpen
                  ? '함께한 펫은 여기 기록돼. 언젠가 귀한 펫도 만날 거야!'
                  : '사냥한 몬스터는 여기 기록돼. ${all.length}칸 모두 채워 보자!'),
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
                                    color: Color(0xFFE5484D),
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
                  backgroundColor: const Color(0xFF1E2250),
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
                    seen: widget.petsSeen, onOpenPets: widget.onOpenPets))
          else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('몬스터 도감 ${have.length} / ${all.length}',
                          style: AppText.title(18)),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 3,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.72,
                        children: [
                          for (final m in all)
                            _MonsterTile(
                              info: m,
                              hunted: purifiedMonsters.contains(m.id),
                              count: huntCounts[m.id] ?? 0,
                              onTap: purifiedMonsters.contains(m.id)
                                  ? () => _showMonster(context, m)
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('희귀·전설 사냥 기록', style: AppText.title(18)),
                      const SizedBox(height: 8),
                      if (records.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: KText(
                              '아직 없어요. 지도에서 파란 이름이나 주황 이름의 몬스터를 찾아보세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: KText(value,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ]),
      );
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile(
      {required this.info, required this.hunted, this.count = 0, this.onTap});

  final MonsterInfo info;
  final bool hunted;

  /// 사냥한 마릿수
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
                          Color(0xFF0B0D26), BlendMode.srcATop),
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
  const _PetCodex({required this.seen, this.onOpenPets});

  final Set<PetSpecies> seen;
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
                Text(info.name,
                    textAlign: TextAlign.center,
                    style: AppText.title(22, color: AppColors.goldBright)),
                const SizedBox(height: 10),
                _Fact(label: '원정 특기', value: '${info.special} (성체: ${info.specialAdult})'),
                _Fact(
                    label: '던전 스킬',
                    value: '${info.skillName} · ${info.skillText} '
                        '(성체: ${info.skillTextAdult})'),
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
              Text('펫 도감 ${seen.length} / ${PetSpecies.values.length}',
                  style: AppText.title(18)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.8,
                children: [
                  for (final s in PetSpecies.values)
                    GestureDetector(
                      onTap: seen.contains(s)
                          ? () => _show(context, PetRules.info(s))
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1E4C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: seen.contains(s)
                                  ? AppColors.goldBright
                                  : AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(children: [
                          Expanded(
                            child: seen.contains(s)
                                ? PetArt(species: s, size: 80)
                                // 11-11 #96: 못 만난 펫은 완전한 검은 실루엣
                                : ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                        Color(0xFF05060F), BlendMode.srcATop),
                                    child: PetArt(species: s, size: 80)),
                          ),
                          Text(seen.contains(s) ? PetRules.info(s).name : '???',
                              style: TextStyle(
                                  color: seen.contains(s)
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ],
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
