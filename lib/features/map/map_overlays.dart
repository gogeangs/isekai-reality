part of 'map_screen.dart';

// 지도 위에 얹는 것들 (묶음 21: map_screen 에서 나눔): 정령 배지, 물약 줄, 던전 줄,
// 발견·몬스터 카드, 지도 키가 없을 때 요약, 원정 목록, 돋보기 버튼

/// 지도 구석 정령 말풍선 (묶음 16 #126). 말이 바뀌면 다시 나오고, 잠시 뒤 접힌다.
/// 누르면 바로 접는다.
class _SpiritCorner extends StatefulWidget {
  const _SpiritCorner({required this.controller});

  final AppController controller;

  @override
  State<_SpiritCorner> createState() => _SpiritCornerState();
}

class _SpiritCornerState extends State<_SpiritCorner> {
  String _current() {
    final c = widget.controller;
    final p = c.player;
    // 묶음 25 #166: 원정 중이면 원정 대사가 먼저 (HP 30% 아래 경고만 그보다 앞)
    final low = c.maxHp > 0 && c.hp / c.maxHp < 0.3;
    final away = low ? null : c.expeditionTalk;
    if (away != null) return away;
    return c.statusLifeLine ??
        BulssiLines.forStatus(
          today: p.today!,
          gauge: p.gauge,
          now: c.now,
          hpRatio: c.maxHp == 0 ? 1 : c.hp / c.maxHp,
          mpRatio: c.mpMax == 0 ? 1 : c.mp / c.mpMax,
          resting: c.resting,
          spiritAway: false,
        );
  }

  @override
  Widget build(BuildContext context) {
    // 묶음 20 #158: 금테 배지 + 오른쪽 말풍선 (꼬리는 배지 쪽). 폭은 우편·설정 버튼 앞까지
    final w = MediaQuery.sizeOf(context).width;
    final c = widget.controller;
    final rush = c.rushableExpedition;
    return SpiritTalkBadge(
      line: _current(),
      bubbleKey: const Key('mapSpiritLine'),
      actionLabel: rush == null ? null : '서두를까?',
      onAction: rush == null ? null : () => showRushSheet(context, c, rush),
      maxBubbleWidth: math.max(140, w - 14 - 44 - 2 - 118),
    );
  }
}

/// 지금 걸린 물약 (11-11 #76): 작은 아이콘 + 남은 시간·전투·걸음
class _BuffBar extends StatelessWidget {
  const _BuffBar({required this.controller, required this.buffs});

  final AppController controller;
  final List<ActiveBuff> buffs;

  @override
  Widget build(BuildContext context) => Center(
        child: Wrap(
          key: const Key('mapBuffs'),
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            // 지친 상태 (11-11 #75): 패배 뒤 1시간, 여관에서 쉬면 풀림
            if (controller.tired) TiredBadge(controller: controller),
            for (final b in buffs)
              Container(
                padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0D26),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PotionIcon(
                      potion: AlchemyRules.byName(b.key),
                      suspicious: b.key.startsWith('?:'),
                      size: 22),
                  const SizedBox(width: 3),
                  Text(controller.buffLeftLabel(b).replaceAll(' 남음', ''),
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      );
}

/// 「지친 상태」 표시 (11-11 #75). 누르면 정령(펫)의 한마디.
class TiredBadge extends StatelessWidget {
  const TiredBadge({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('tiredBadge'),
        onTap: () => showTopNotice(context, AppController.tiredLine),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
          decoration: BoxDecoration(
            color: const Color(0xE63A1630),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE07A7A)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bedtime_rounded, size: 16, color: Color(0xFFF2B0B0)),
            SizedBox(width: 3),
            Text('지친 상태',
                style: TextStyle(
                    color: Color(0xFFF7D2D2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// 지도 아래 던전 띠: 열쇠 · 게이지 · [던전 열기] (11-11 #68)
class DungeonStrip extends StatelessWidget {
  const DungeonStrip({super.key, required this.gauge, this.onOpen});

  final DungeonGaugeState gauge;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final keys = gauge.keysAvailable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141638),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(children: [
        const GameIcon('key', size: 24),
        const SizedBox(width: 4),
        Text('열쇠 $keys',
            key: const Key('stripKeys'),
            style: const TextStyle(
                color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlowBar(ratio: gauge.ratio, colors: BarColors.gauge, height: 7),
              const SizedBox(height: 2),
              Text(
                  gauge.dailyKeyLimitReached
                      ? '오늘은 다 모았어요'
                      : '${comma(gauge.stepsIntoNextKey)} / ${comma(gauge.stepsPerKey)}보',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 열쇠가 있으면 금색으로 빛나고, 없으면 흐리게
        TextButton(
          key: const Key('openDungeon'),
          style: gameButtonStyle(gold: true).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(92, 38)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14)),
            textStyle: const WidgetStatePropertyAll(TextStyle(
                fontFamily: 'Title', fontWeight: FontWeight.w700, fontSize: 14)),
            shadowColor: const WidgetStatePropertyAll(AppColors.gold),
            elevation: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? 0 : 6),
          ),
          onPressed: keys > 0 ? onOpen : null,
          child: const Text('던전 열기', maxLines: 1),
        ),
      ]),
    );
  }
}

/// 장소 종류별 지도 표시 그림
String placeIconAsset(PlaceKind kind) => switch (kind) {
      PlaceKind.labyrinthGate => 'assets/images/map_gate.webp',
      PlaceKind.spiritLake => 'assets/images/map_lake.webp',
    };

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.place, required this.onClose});

  final GamePlace place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText('새 장소 발견! · ${place.name}',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            KText('현실: ${place.realName} · 경험치 +${RuleConstants.newPlaceExp}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            BulssiLine(line: _discoveryLine(place.kind)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    minimumSize: const Size(64, 44)),
                child: const Text('좋아'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _discoveryLine(PlaceKind kind) => switch (kind) {
        PlaceKind.labyrinthGate => '여기가 미궁 입구야! 여기서 던전을 열면 보상이 1.5배야.',
        PlaceKind.spiritLake => '물의 정령들이 반짝이고 있어. 비 오는 날엔 더 많아진대!',
      };
}

class _MonsterCard extends StatelessWidget {
  const _MonsterCard({required this.spawn, required this.onPurify});

  final FieldSpawn spawn;
  final VoidCallback onPurify;

  @override
  Widget build(BuildContext context) {
    final info = spawn.info;
    return Material(
      color: AppColors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gauge, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          MonsterPicture(monster: info.id, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${josa(spawn.name, '이/가')} 나타났어!',
                    style: TextStyle(
                        color: spawn.modifiers.isEmpty
                            ? AppColors.goldBright
                            : modGradeColor(spawn.grade),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const KText('멈춰 선 다음 사냥해 주세요',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              ],
            ),
          ),
          FilledButton(
            key: const Key('monsterCardHunt'),
            onPressed: onPurify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gauge,
              foregroundColor: AppColors.night,
              minimumSize: const Size(88, 48),
            ),
            child: const Text('사냥하기'),
          ),
        ]),
      ),
    );
  }
}

/// 네이버 지도 Client ID 가 없을 때(테스트, 설정 전) 보여 주는 화면
class _ExploreSummary extends StatelessWidget {
  const _ExploreSummary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final visited = controller.everVisitedPlaceIds;
    final fix = controller.lastFix;
    return NightBackground(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 140, 16, 24),
        children: [
          const BulssiLine(
              line: '지도를 열려면 네이버 지도 키가 필요해. 그동안은 탐험 기록을 보여 줄게!'),
          const SizedBox(height: 16),
          if (fix != null)
            KText(
              '현재 위치 ${fix.point.lat.toStringAsFixed(4)}, '
              '${fix.point.lng.toStringAsFixed(4)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          KText(
            '오늘 남은 몬스터 ${controller.todaySpawns.length}마리 · '
            '가까이(${RuleConstants.fieldEncounterRadiusM.round()}m) 가면 만날 수 있어요',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _ExpeditionList(controller: controller),
          const SizedBox(height: 12),
          for (final place in controller.area.places)
            ListTile(
              leading: Image.asset(
                visited.contains(place.id)
                    ? placeIconAsset(place.kind)
                    : 'assets/images/map_unknown.webp',
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.place_rounded,
                    color: AppColors.gold),
              ),
              title: Text(
                visited.contains(place.id) ? place.name : '???',
                style: const TextStyle(color: AppColors.text),
              ),
              subtitle: Text(place.realName,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

/// 지도 없이 볼 때: 정령을 보낼 수 있는 몬스터 목록
class _ExpeditionList extends StatelessWidget {
  const _ExpeditionList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final actives = c.activeExpeditions;
    if (actives.isNotEmpty && (!c.farewellDone || c.idlePets.isEmpty)) {
      return Column(children: [
        for (final ex in actives) ...[
          ExpeditionCard(controller: c, ex: ex),
          const SizedBox(height: 6),
        ],
      ]);
    }
    // 가까운 몬스터부터 (거리는 MP로만 막는다, 11-10)
    final from = c.lastFix?.point;
    final reachable = [...c.todaySpawns];
    if (from != null) {
      reachable.sort((a, b) =>
          a.point.distanceTo(from).compareTo(b.point.distanceTo(from)));
    }
    return OrnatePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText('${c.farewellDone ? '펫' : '정령'} 원정 · MP ${c.mp} / ${c.mpMax}',
                style: AppText.title(16)),
            const SizedBox(height: 4),
            Text(
              reachable.isEmpty
                  ? '근처에 남은 몬스터가 없어요.'
                  : '근처 몬스터 ${reachable.length}마리 · 가까운 곳부터 보여 드려요. '
                      '100m마다 MP ${RuleConstants.expeditionMpPer100m}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            for (final s in reachable.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MonsterPicture(monster: s.monster, size: 40),
                title: Text(s.name,
                    style: TextStyle(color: modGradeColor(s.grade))),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.gold),
                onTap: () => showSpawnSheet(context, c, s),
              ),
            // 채집 자리 (11-11 #56): 가까운 3곳
            for (final h in (c.harvestSpots.toList()
                  ..sort((a, b) => a.point
                      .distanceTo(c.lastPoint ?? a.point)
                      .compareTo(b.point.distanceTo(c.lastPoint ?? b.point))))
                .take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MaterialIcon(h.info.base, size: 36),
                title: Text(h.info.name,
                    style: const TextStyle(color: AppColors.text)),
                subtitle: Text(
                    '남은 횟수 ${c.harvestCharges(h)} · '
                    '${c.lastPoint == null ? '' : '${h.point.distanceTo(c.lastPoint!).round()}m'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.gold),
                onTap: () => showHarvestSheet(context, c, h),
              ),
          ],
        ),
      ),
    );
  }
}

/// 지도 돋보기 버튼 (묶음 19 #154): 오늘 무료 감정이 남아 있으면 금빛 점
class _LensButton extends StatelessWidget {
  const _LensButton({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final free = c.lensFreeToday;
    return Semantics(
      button: true,
      label: '마법 돋보기',
      child: GestureDetector(
        key: const Key('mapLens'),
        onTap: () {
          if (!c.canAppraise) {
            showTopNotice(context, '잡화상에서 살 수 있어요',
                icon: Icons.storefront_rounded);
            return;
          }
          openLens(Navigator.of(context), c);
        },
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xE6141638),
              border: Border.all(
                  color: free ? AppColors.goldBright : AppColors.gold,
                  width: free ? 2 : 1.3),
              boxShadow: free
                  ? [
                      BoxShadow(
                          color: AppColors.goldBright.withValues(alpha: 0.6),
                          blurRadius: 12),
                    ]
                  : null,
            ),
            child: const Center(child: GameIcon('lens', size: 32)),
          ),
          if (free)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                key: const Key('mapLensFree'),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.goldBright,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.abyss, width: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
