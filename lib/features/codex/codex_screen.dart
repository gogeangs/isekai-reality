import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/modifier_view.dart';
import '../bulssi/bulssi_bubble.dart';

/// 도감 (11-11 #41): 탭 없이 몬스터 한 목록. 속성 슬라임도 각각 한 칸.
/// 목록 아래에 「희귀·전설 사냥 기록」. 칭호는 프로필로 옮겼다.
class CodexScreen extends StatelessWidget {
  const CodexScreen({
    super.key,
    required this.purifiedMonsters,
    this.huntCounts = const {},
    this.modHunts = const {},
  });

  /// 한 번이라도 사냥한 몬스터
  final Set<MonsterId> purifiedMonsters;

  /// 종류별 사냥한 마릿수
  final Map<MonsterId, int> huntCounts;

  /// 희귀·전설 수식어 몬스터 사냥 기록 ([ModifierRules.codexKey] → 마릿수)
  final Map<String, int> modHunts;

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
                Text(m.name,
                    textAlign: TextAlign.center,
                    style: AppText.title(22, color: AppColors.goldBright)),
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
              line: '사냥한 몬스터는 여기 기록돼. ${all.length}칸 모두 채워 보자!'),
          const SizedBox(height: 10),
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
    };
