part of '../battle_view.dart';

/// 배경 그림이 없을 때 대신 쓸 그림 (바다 → 물가, 나머지 → 기본)
String backgroundFallback(String? bg) => switch (bg) {
      'assets/images/bg_field_sea.webp' => 'assets/images/bg_field_water.webp',
      _ => 'assets/images/bg_battle.webp',
    };

/// tired: HP 0으로 싸울 수 없을 때 (11-10)
enum HeroPose { idle, attack, victory, tired }

/// 묶음 73 #306: 이야기 동료 공격 그림 (640×640 × 6칸, 발 바닥 약 620)
/// 1 준비 → 2 힘 모으기 → 3 휘두르기 시작 → 4 맞히는 순간 → 5 마무리 → 6 다시 준비(→ 1)
class AllyAttackSheet {
  AllyAttackSheet._();

  static const frames = 6;

  /// 이야기 동료 (이름 없는 동료 ally_job_* 는 통 그림)
  static const story = {'lian', 'garen', 'nia', 'barkan', 'popo', 'sera', 'teo'};

  /// 2~6칸 시간 (ms). 1칸은 기다리는 동안
  static const durations = [100, 80, 160, 100, 120];
  static int get totalMs => durations.fold(0, (a, b) => a + b);

  /// 통 그림 경로 → 공격 칸 그림 (없으면 null)
  static String? sheetOf(String? art) {
    if (art == null) return null;
    final m = RegExp(r'ally_([a-z]+)\.webp$').firstMatch(art);
    if (m == null || !story.contains(m.group(1))) return null;
    return 'assets/images/ally_${m.group(1)}_attack.webp';
  }

  /// 공격 시작부터 [ms] 뒤의 칸 (0~5)과, 4칸부터 흐른 비율 (0~1, 그 전이면 null)
  static (int, double?) frameAt(double ms) {
    if (ms < 0 || ms >= totalMs) return (0, null);
    var at = 0;
    for (var k = 0; k < durations.length; k++) {
      if (ms < at + durations[k]) {
        final hitAt = durations[0] + durations[1]; // 4칸이 시작하는 때
        return (k + 1, ms >= hitAt ? (ms - hitAt) / (totalMs - hitAt) : null);
      }
      at += durations[k];
    }
    return (0, null);
  }
}

/// 가로로 이어 붙인 정사각 칸 그림에서 한 칸만 (칸 바닥에 맞춰)
class SheetFrame extends StatelessWidget {
  const SheetFrame(
      {super.key, required this.asset, required this.frames, required this.frame, this.fallback});

  final String asset;
  final int frames;
  final int frame;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: s,
            height: s,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: s * frames,
                maxWidth: s * frames,
                child: Transform.translate(
                  offset: Offset(-frame * s, 0),
                  child: Image.asset(asset,
                      width: s * frames,
                      height: s,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => SizedBox(
                          width: s * frames,
                          height: s,
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(width: s, height: s, child: fallback)))),
                ),
              ),
            ),
          ),
        );
      });
}

/// 각성자 그림 (묶음 73 #261: 맨손 새 주인공).
/// 서기·승리·지침은 768×1024 한 장, 공격은 640×800 여섯 칸을 [t](0~1)에 따라 넘긴다.
/// 두 그림 모두 발끝이 아래에서 20px 위라서, 768×1024 칸 바닥에 맞춰 그린다.
class HeroSprite extends StatelessWidget {
  const HeroSprite(
      {super.key, required this.look, required this.pose, this.t = 0, this.job, this.frame});

  final HeroLook look;
  final HeroPose pose;

  /// 묶음 76 #307: 직업 그림 ('warrior' …). 서기 · 공격은 hero_<job>_attack 여섯 칸
  /// (대기 = 1칸), 승리 · 지침은 그대로
  final String? job;

  /// 직업 그림 공격 칸 (0~5). 없으면 [t] 로 정한다
  final int? frame;

  /// 공격 동작 진행 (0~1). 공격이 아니면 쓰지 않는다
  final double t;

  static const attackFrames = 6;

  /// 공격 [t] 에서 보여 줄 칸 (0~5)
  static int frameAt(double t) =>
      (t.clamp(0.0, 1.0) * attackFrames).floor().clamp(0, attackFrames - 1);

  bool get _jobSheet => job != null && (pose == HeroPose.attack || pose == HeroPose.idle);

  String get _asset => _jobSheet
      ? 'assets/images/hero_${job}_attack_${look.name}.webp'
      : 'assets/images/hero_${pose.name}_${look.name}.webp';

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object __, StackTrace? ___) =>
        const Icon(Icons.person_rounded, size: 140, color: AppColors.textMuted);
    if (!_jobSheet && pose != HeroPose.attack) {
      return Image.asset(_asset,
          fit: BoxFit.contain, semanticLabel: '각성자', errorBuilder: fallback);
    }
    final frame = _jobSheet
        ? (pose == HeroPose.idle ? 0 : (this.frame ?? frameAt(t)))
        : frameAt(t);
    return AspectRatio(
      aspectRatio: 768 / 1024,
      child: LayoutBuilder(builder: (context, box) {
        final fw = box.maxWidth * 640 / 768;
        final fh = box.maxHeight * 800 / 1024;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: Key('heroFrame_$frame'),
            width: fw,
            height: fh,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: fw * attackFrames,
                maxWidth: fw * attackFrames,
                child: Transform.translate(
                  offset: Offset(-frame * fw, 0),
                  child: Image.asset(_asset,
                      width: fw * attackFrames,
                      height: fh,
                      fit: BoxFit.fill,
                      semanticLabel: '각성자',
                      errorBuilder: fallback),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 몬스터 그림. 그림 파일이 없으면 아이콘으로 대신한다.
class MonsterPicture extends StatelessWidget {
  const MonsterPicture({
    super.key,
    required this.monster,
    this.size = 64,
    this.defeated = false,
    this.reveal,
    this.crystal,
    this.tint,
  });

  final MonsterId monster;
  final double size;

  /// 묶음 50 석상 병사: 섬 속성 색을 살짝 입힌다 (ARGB)
  final int? tint;

  /// 묶음 43 속성 허수아비: 가슴 수정에 그 속성 색
  final Color? crystal;

  /// 묶음 34 잿빛 군주: 안개 판 위에 얼굴 판을 겹친다 (0 안개 ~ 1 얼굴)
  final double? reveal;

  /// true 면 쓰러진 모습 (기울어지며 흐려진다, 11-10 사냥)
  final bool defeated;

  /// 그림을 흑백으로 바꾼 뒤 [argb] 색을 입힌다 (투명한 곳은 그대로)
  static ColorFilter tintFilter(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255 * 1.35;
    final g = ((argb >> 8) & 0xFF) / 255 * 1.35;
    final b = (argb & 0xFF) / 255 * 1.35;
    return ColorFilter.matrix([
      0.30 * r, 0.59 * r, 0.11 * r, 0, 0,
      0.30 * g, 0.59 * g, 0.11 * g, 0, 0,
      0.30 * b, 0.59 * b, 0.11 * b, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  static IconData iconOf(MonsterId id) => switch (id) {
        MonsterId.ashSlime || MonsterId.slime => Icons.water_drop_rounded,
        MonsterId.ashRage => Icons.local_fire_department_rounded,
        MonsterId.ashSorrow => Icons.water_rounded,
        MonsterId.ashGreed => Icons.diamond_rounded,
        MonsterId.ashFear => Icons.dark_mode_rounded,
        MonsterId.ashLonely => Icons.air_rounded,
        MonsterId.ashKing => Icons.cloud_rounded,
        MonsterId.dummy ||
        MonsterId.dummyHard ||
        MonsterId.dummyElement =>
          Icons.sports_martial_arts_rounded,
        MonsterId.trainingGolem => Icons.smart_toy_rounded,
        MonsterId.guardWind => Icons.air_rounded,
        MonsterId.guardThunder => Icons.bolt_rounded,
        MonsterId.guardLight => Icons.wb_sunny_rounded,
        MonsterId.guardIce => Icons.ac_unit_rounded,
        MonsterId.guardWater => Icons.waves_rounded,
        MonsterId.stoneSoldier => Icons.shield_rounded,
        // 묶음 69 #281: Lv.50 지도 몬스터 (그림이 오기 전 아이콘)
        MonsterId.doppelganger || MonsterId.dullahan || MonsterId.deathKnight => Icons.nights_stay_rounded,
        MonsterId.arachne || MonsterId.basilisk => Icons.bug_report_rounded,
        MonsterId.sphinx => Icons.help_rounded,
        MonsterId.clockworkKnight => Icons.settings_rounded,
        MonsterId.centaur || MonsterId.owlbear => Icons.forest_rounded,
        MonsterId.kelpie || MonsterId.naga => Icons.waves_rounded,
        MonsterId.roc => Icons.flight_rounded,
        MonsterId.werewolf => Icons.pets_rounded,
        MonsterId.goblinRaider => Icons.hardware_rounded,
        MonsterId.skeletonGuard => Icons.shield_moon_rounded,
        MonsterId.harpy => Icons.air_rounded,
        MonsterId.ogre => Icons.landscape_rounded,
        MonsterId.ashHounds => Icons.pets_rounded,
        MonsterId.ashArmor => Icons.security_rounded,
        MonsterId.ashWolfAlpha => Icons.nights_stay_rounded,
        MonsterId.partyGolem => Icons.terrain_rounded,
        MonsterId.partyHydra => Icons.waves_rounded,
        MonsterId.partyWyvern => Icons.flight_rounded,
        MonsterId.partyKraken => Icons.water_rounded,
        // 묶음 57: 지역 2~5 (그림이 있어 아이콘은 거의 안 씀)
        MonsterId.orcMerc ||
        MonsterId.koboldMiner ||
        MonsterId.gargoyle ||
        MonsterId.livingArmor ||
        MonsterId.orcCaptain ||
        MonsterId.ashCart ||
        MonsterId.metalColossus =>
          Icons.hardware_rounded,
        MonsterId.treant ||
        MonsterId.giantSpider ||
        MonsterId.dryad ||
        MonsterId.woodWolf ||
        MonsterId.spiderQueen ||
        MonsterId.ashElder ||
        MonsterId.ashTortoise =>
          Icons.forest_rounded,
        MonsterId.vampireBat ||
        MonsterId.wraith ||
        MonsterId.ghoul ||
        MonsterId.cultZealot ||
        MonsterId.cultPriests ||
        MonsterId.ashCaptain ||
        MonsterId.ashBeasts =>
          Icons.nights_stay_rounded,
        MonsterId.salamander ||
        MonsterId.ifrit ||
        MonsterId.koboldrake ||
        MonsterId.cultFlamePriest ||
        MonsterId.youngRedDragon ||
        MonsterId.orben ||
        MonsterId.orbenAsh ||
        MonsterId.phoenixMother ||
        MonsterId.raidDragon =>
          Icons.local_fire_department_rounded,
        MonsterId.raidGiant => Icons.wb_sunny_rounded,
        MonsterId.raidLich => Icons.dangerous_rounded,
        MonsterId.raidTortoise => Icons.landscape_rounded,
        MonsterId.wildGriffin || MonsterId.wildKnightCaptain => Icons.flare_rounded,
        MonsterId.wildTroll || MonsterId.wildRuneGolem => Icons.hardware_rounded,
        MonsterId.wildBoar || MonsterId.wildElfArcher => Icons.forest_rounded,
        MonsterId.wildLizardman || MonsterId.wildBanshee => Icons.nights_stay_rounded,
        MonsterId.wildLavaGolem || MonsterId.wildDragonCaptain => Icons.local_fire_department_rounded,
        MonsterId.garrisonClone ||
        MonsterId.blackGuard ||
        MonsterId.blackCaptain ||
        MonsterId.cloneWarrior ||
        MonsterId.cloneKnight ||
        MonsterId.cloneArcher ||
        MonsterId.cloneMage ||
        MonsterId.clonePriest ||
        MonsterId.cloneRogue =>
          Icons.shield_rounded,
        MonsterId.labyrinthBat => Icons.nights_stay_rounded,
        MonsterId.roughWaterSpirit => Icons.waves_rounded,
        MonsterId.shadowButterfly => Icons.flutter_dash_rounded,
        MonsterId.lostStoneSpirit => Icons.landscape_rounded,
        MonsterId.labyrinthWarden => Icons.shield_moon_rounded,
        MonsterId.fireSlimeKing => Icons.local_fire_department_rounded,
        MonsterId.frostWolfKing => Icons.ac_unit_rounded,
        MonsterId.ancientTreant => Icons.park_rounded,
        MonsterId.shadowBatQueen => Icons.dark_mode_rounded,
        MonsterId.thunderGriffin => Icons.bolt_rounded,
        MonsterId.giantRat => Icons.pest_control_rodent_rounded,
        MonsterId.hornRabbit => Icons.cruelty_free_rounded,
        MonsterId.babyBoar => Icons.savings_rounded,
        MonsterId.fireSlime ||
        MonsterId.waterSlime ||
        MonsterId.windSlime ||
        MonsterId.earthSlime ||
        MonsterId.lightSlime ||
        MonsterId.darkSlime ||
        MonsterId.iceSlime ||
        MonsterId.thunderSlime ||
        MonsterId.metalSlime ||
        MonsterId.poisonSlime =>
          Icons.water_drop_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = Monsters.info(monster);
    final r = reveal;
    if (r != null && !defeated) {
      final k = r.clamp(0.0, 1.0);
      return SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          Opacity(
            opacity: 1 - 0.7 * k,
            child: Image.asset(info.asset,
                width: size,
                height: size,
                semanticLabel: info.name,
                errorBuilder: (_, __, ___) => Icon(iconOf(monster),
                    size: size * 0.7, color: const Color(0xFFB8B2C8))),
          ),
          Opacity(
            key: const Key('ashKingFace'),
            opacity: 0.12 + 0.88 * k,
            child: Image.asset(
                'assets/images/monster_${monster.name}_face.webp',
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ]),
      );
    }
    final picture = Image.asset(
      info.asset,
      width: size,
      height: size,
      semanticLabel: info.name,
      errorBuilder: (_, __, ___) => info.tint != null
          // 속성 슬라임 그림이 오기 전에는 기본 슬라임 그림에 색을 입힌다
          ? ColorFiltered(
              colorFilter: tintFilter(info.tint!),
              child: Image.asset(
                Monsters.info(MonsterId.ashSlime).asset,
                width: size,
                height: size,
                semanticLabel: info.name,
              ),
            )
          : Icon(
              iconOf(monster),
              size: size * 0.7,
              color: info.isBoss && info.element != null
                  ? elementColor(info.element)
                  : const Color(0xFFB8B2C8),
              semanticLabel: info.name,
            ),
    );
    if (!defeated && tint != null) {
      return ColorFiltered(
        key: const Key('monsterTint'),
        colorFilter: ColorFilter.mode(
            Color(tint!).withValues(alpha: 0.38), BlendMode.srcATop),
        child: picture,
      );
    }
    if (!defeated && crystal != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          picture,
          // 묶음 75 #323: 실제 가슴 수정 자리 (가운데 0.453, 0.551 · 지름 0.17)
          Positioned(
            key: const Key('dummyCrystal'),
            left: size * 0.368,
            top: size * 0.466,
            width: size * 0.17,
            height: size * 0.17,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.9),
                    crystal!.withValues(alpha: 0.85),
                    crystal!.withValues(alpha: 0),
                  ], stops: const [0, 0.45, 1]),
                ),
              ),
            ),
          ),
        ]),
      );
    }
    if (!defeated) return picture;
    // 사냥한 몬스터는 쓰러지고 사라진다
    return Opacity(
      opacity: 0.18,
      child: Transform.translate(
        offset: Offset(0, size * 0.12),
        child: Transform.rotate(angle: 0.5, child: picture),
      ),
    );
  }
}

/// 사냥 결과의 몬스터 (묶음 18 #149): 흐리지 않고 원래 색 그대로, 뒤로 따뜻한
/// 정화 빛이 번지고 천천히 숨 쉬듯 움직인다 (편안해진 느낌). 모든 몬스터에 쓴다.
class PurifiedMonster extends StatefulWidget {
  const PurifiedMonster({super.key, required this.monster, this.size = 140});

  final MonsterId monster;
  final double size;

  @override
  State<PurifiedMonster> createState() => _PurifiedMonsterState();
}

class _PurifiedMonsterState extends State<PurifiedMonster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true, count: 4);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final s = widget.size;
    return SizedBox(
      key: const Key('purifiedMonster'),
      width: s * 1.5,
      height: s * 1.25,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = still ? 0.5 : Curves.easeInOut.transform(_a.value);
          return Stack(alignment: Alignment.center, children: [
            // 따뜻한 정화 빛
            Container(
              width: s * (1.35 + 0.08 * t),
              height: s * (1.35 + 0.08 * t),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFFF4D2).withValues(alpha: 0.75),
                  const Color(0xFFFFC96B).withValues(alpha: 0.35),
                  const Color(0x00FFC96B),
                ], stops: const [0, 0.5, 1]),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -3 * t),
              child: Transform.scale(
                scale: 1 + 0.025 * t,
                child: MonsterPicture(monster: widget.monster, size: s),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
