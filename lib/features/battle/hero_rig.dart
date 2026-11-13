import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/rules/equipment_rules.dart';
import '../../data/storage/record_store.dart';

/// #81 2단계 (묶음 14): 각성자 부위 애니메이션.
///
/// 부위 그림 13장(assets/images/rig/hero_<남녀>_<부위>.png)을 뼈대에 붙여 돌린다.
/// 뼈대·회전축·그리는 순서는 [HeroRigData] 한곳에 모아 두었다 (나중에 Spine 으로 옮길 때 그대로 쓴다).
/// 그림이 하나라도 없으면 [fallback](지금의 통 그림)을 그대로 보여 준다.

/// 전투 동작 6가지
enum RigAction { idle, attack, guard, hit, victory, tired }

/// 무기 종류 (장비마다 하나). 없으면 맨손.
enum WeaponKind { sword, axe, dagger, spear, staff }

/// 장비 → 무기 종류 (보스 장비는 가장 가까운 종류로)
WeaponKind? weaponKindOf(EquipBase? base) => switch (base) {
      EquipBase.dagger ||
      EquipBase.hornDagger ||
      EquipBase.nightWeapon =>
        WeaponKind.dagger,
      EquipBase.staff || EquipBase.flameWeapon => WeaponKind.staff,
      EquipBase.wardenWeapon || EquipBase.frostWeapon => WeaponKind.sword,
      EquipBase.groveWeapon => WeaponKind.axe,
      EquipBase.stormWeapon => WeaponKind.spear,
      _ => null,
    };

/// 뼈 하나: 그림 이름, 그림 안 회전축(px), 부모 뼈, 부모 그림 안 붙는 자리(px)
class RigBone {
  const RigBone(this.name, this.image, this.pivot, this.parent, this.attach);
  final String name;
  final String image;
  final Offset pivot;
  final String? parent;
  final Offset attach;
}

/// 뼈대 자료 (반 크기 부위 그림 기준 px). 각도는 시계 방향 +, 도(°).
class HeroRigData {
  HeroRigData._();

  static const List<RigBone> bones = [
    RigBone('torso', 'torso', Offset(205, 280), null, Offset.zero),
    RigBone('head', 'head', Offset(185, 315), 'torso', Offset(215, 45)),
    RigBone('tail', 'tail', Offset(220, 35), 'torso', Offset(175, 230)),
    RigBone('arm_b_up', 'arm_back_upper', Offset(80, 35), 'torso', Offset(245, 105)),
    RigBone('arm_b_fo', 'arm_back_fore', Offset(30, 50), 'arm_b_up', Offset(55, 150)),
    RigBone('hand_b', 'hand_back', Offset(18, 45), 'arm_b_fo', Offset(118, 52)),
    RigBone('arm_f_up', 'arm_front_upper', Offset(70, 30), 'torso', Offset(200, 110)),
    RigBone('arm_f_fo', 'arm_front_fore', Offset(30, 50), 'arm_f_up', Offset(45, 155)),
    RigBone('hand_f', 'hand_front', Offset(22, 62), 'arm_f_fo', Offset(125, 52)),
    RigBone('leg_b_th', 'leg_back_thigh', Offset(75, 30), 'torso', Offset(250, 255)),
    RigBone('leg_b_sh', 'leg_back_shin', Offset(70, 22), 'leg_b_th', Offset(60, 180)),
    RigBone('leg_f_th', 'leg_front_thigh', Offset(75, 30), 'torso', Offset(180, 258)),
    RigBone('leg_f_sh', 'leg_front_shin', Offset(70, 22), 'leg_f_th', Offset(60, 180)),
  ];

  static final Map<String, RigBone> byName = {for (final b in bones) b.name: b};

  /// 부위 그림 13장
  static final List<String> partImages =
      [for (final b in bones) b.image];

  /// 그리는 순서 (뒤 → 앞). 'weapon' 은 앞손 바로 뒤.
  static const List<String> order = [
    'tail', 'arm_b_up', 'arm_b_fo', 'hand_b', 'leg_b_th', 'leg_b_sh',
    'leg_f_th', 'leg_f_sh', 'torso', 'head',
    'arm_f_up', 'arm_f_fo', 'weapon', 'hand_f',
  ];

  /// 팔을 머리 위로 들면(앞팔 위쪽 각도가 이보다 작으면) 앞팔을 머리 뒤에 그린다
  /// (머리가 커서 앞에 그리면 얼굴을 가린다)
  static const double raisedArm = -80;

  /// 그림 틀 (뼈대 좌표): 이 안에 발이 아래에 닿게 그린다
  static const Rect frame = Rect.fromLTWH(40, 0, 560, 945);
  static const Offset root = Offset(330, 560);

  /// 무기 그림 (512×1024, 끝이 위): 손잡이 자리·크기·앞손에 붙는 자리
  static const Map<WeaponKind, Offset> grip = {
    WeaponKind.sword: Offset(256, 820),
    WeaponKind.axe: Offset(256, 780),
    WeaponKind.dagger: Offset(256, 760),
    WeaponKind.spear: Offset(250, 700),
    WeaponKind.staff: Offset(256, 800),
  };
  static const double weaponScale = 0.32;
  static const Offset weaponAttach = Offset(72, 55);

  /// 묶음 19 #152: 상황에 따라 바꿔 그리는 부위 (없으면 원래 그림)
  /// - 무기를 들면 앞손 → 무기 쥔 손 (구멍으로 무기가 지나감)
  /// - 앞팔을 머리 위로 들면 앞팔 위쪽 → 들어 올린 앞팔
  static const List<String> extraImages = ['hand_grip', 'arm_front_raised'];

  /// 무기 쥔 손: 손목(회전축)과 주먹 가운데(무기 자리), 그림 px
  static const Map<HeroLook, (Offset, Offset)> grip2 = {
    HeroLook.male: (Offset(20, 69), Offset(79, 56)),
    HeroLook.female: (Offset(18, 61), Offset(64, 51)),
  };

  /// 들어 올린 앞팔: 어깨(아래 둥근 끝)와 팔꿈치(위 둥근 끝), 그림 px
  static const Map<HeroLook, (Offset, Offset)> raised = {
    HeroLook.male: (Offset(40, 182), Offset(56, 25)),
    HeroLook.female: (Offset(46, 182), Offset(49, 25)),
  };

  static String partAsset(HeroLook look, String image) =>
      'assets/images/rig/hero_${look.name}_$image.webp';
  static String weaponAsset(WeaponKind k) => 'assets/images/weapon_${k.name}.webp';
}

/// 자세 하나: 뼈 각도(°) + 무기 세계 각도 W + 몸 위치 dx·dy (px)
class RigPose {
  const RigPose(this.angles);
  final Map<String, double> angles;

  double operator [](String k) => angles[k] ?? 0;

  static const RigPose stand = RigPose({
    'torso': 0, 'head': 0, 'tail': 8,
    'arm_b_up': 10, 'arm_b_fo': 95, 'hand_b': -5,
    'arm_f_up': -10, 'arm_f_fo': 80, 'hand_f': 0,
    'leg_b_th': -4, 'leg_b_sh': 2, 'leg_f_th': 6, 'leg_f_sh': -4,
    'W': 25, 'dx': 0, 'dy': 0,
  });

  /// 서기 자세에서 바꿀 것만
  factory RigPose.from(Map<String, double> change) =>
      RigPose({...stand.angles, ...change});

  RigPose lerp(RigPose b, double u) => RigPose({
        for (final k in {...angles.keys, ...b.angles.keys})
          k: this[k] + (b[k] - this[k]) * u,
      });

  /// 서기 자세 쪽으로 [k] 만큼만 (동작 줄이기)
  RigPose damp(double k) => RigPose({
        for (final e in angles.entries)
          e.key: (e.key == 'dx' || e.key == 'dy')
              ? e.value * k
              : stand[e.key] + (e.value - stand[e.key]) * k,
      });

  RigPose plus(Map<String, double> d) =>
      RigPose({...angles, for (final e in d.entries) e.key: this[e.key] + e.value});
}

/// 동작별 열쇠 자세 (시간 0~1)
class RigMotions {
  RigMotions._();

  static RigPose _p(Map<String, double> m) => RigPose.from(m);
  static const RigPose _s = RigPose.stand;

  static final Map<String, List<(double, RigPose)>> keys = {
    // 검: 뒤로 젖혔다가 옆으로 베기
    'attack_sword': [
      (0, _s),
      (0.3, _p({'arm_f_up': 45, 'arm_f_fo': 40, 'W': -110, 'torso': -6, 'head': -3, 'dx': -10})),
      (0.55, _p({'arm_f_up': -45, 'arm_f_fo': -10, 'W': 100, 'torso': 10, 'dx': 25, 'leg_f_th': -10, 'leg_b_th': 12})),
      (1, _s),
    ],
    // 도끼: 머리 위로 들어 내리찍기
    'attack_axe': [
      (0, _s),
      (0.35, _p({'arm_f_up': -150, 'arm_f_fo': -20, 'W': -40, 'torso': -8, 'head': -4})),
      (0.6, _p({'arm_f_up': -30, 'arm_f_fo': 30, 'W': 150, 'torso': 14, 'dx': 20, 'dy': 8})),
      (1, _s),
    ],
    // 단검: 빠르게 두 번 찌르기
    'attack_dagger': [
      (0, _s),
      (0.18, _p({'arm_f_up': -35, 'arm_f_fo': -15, 'W': 95, 'torso': 10, 'dx': 22})),
      (0.33, _p({'arm_f_up': -10, 'arm_f_fo': 70, 'W': 60, 'dx': 10})),
      (0.52, _p({'arm_f_up': -35, 'arm_f_fo': -15, 'W': 100, 'torso': 10, 'dx': 28})),
      (1, _s),
    ],
    // 창: 당겼다가 길게 찌르기
    'attack_spear': [
      (0, _s),
      (0.3, _p({'arm_f_up': 25, 'arm_f_fo': 110, 'W': 90, 'torso': -4, 'dx': -10})),
      (0.55, _p({'arm_f_up': -40, 'arm_f_fo': -10, 'W': 90, 'torso': 12, 'dx': 35, 'leg_f_th': -14, 'leg_b_th': 14})),
      (1, _s),
    ],
    // 지팡이: 높이 들어 마법 날리기
    'attack_staff': [
      (0, _s),
      (0.4, _p({'arm_f_up': -150, 'arm_f_fo': -15, 'W': -5, 'torso': -6, 'head': -6})),
      (0.6, _p({'arm_f_up': -140, 'arm_f_fo': -20, 'W': 15, 'torso': -4, 'head': -5})),
      (1, _s),
    ],
    // 맨손: 주먹 지르기
    'attack_none': [
      (0, _s),
      (0.3, _p({'arm_f_up': 25, 'arm_f_fo': 110, 'torso': -4, 'dx': -8})),
      (0.55, _p({'arm_f_up': -40, 'arm_f_fo': -10, 'torso': 12, 'dx': 30})),
      (1, _s),
    ],
    'guard': [
      (0, _s),
      (0.3, _guard),
      (0.75, _guard),
      (1, _s),
    ],
    'hit': [
      (0, _s),
      (0.3, _p({'torso': -14, 'head': -12, 'arm_f_up': 25, 'arm_b_up': 30, 'dx': -20, 'W': 40})),
      (1, _s),
    ],
    'victory': [
      (0, _p({'arm_f_up': -155, 'arm_f_fo': -15, 'W': -5, 'torso': -4, 'head': -8, 'arm_b_up': -20, 'arm_b_fo': 60})),
    ],
    'tired': [
      (0, _p({'torso': 16, 'head': 22, 'arm_f_up': 12, 'arm_f_fo': 90, 'W': 150, 'leg_f_th': -28, 'leg_f_sh': 34, 'leg_b_th': -20, 'leg_b_sh': 28, 'dy': 34, 'dx': -4})),
    ],
  };

  static final RigPose _guard = RigPose.from({
    'arm_f_up': -35, 'arm_f_fo': -95, 'W': -10, 'torso': -8, 'head': -4,
    'leg_f_th': -12, 'leg_f_sh': 10, 'dy': 6, 'dx': -6,
  });

  static String keyOf(RigAction a, WeaponKind? w) => switch (a) {
        RigAction.attack => 'attack_${w?.name ?? 'none'}',
        RigAction.idle => 'idle',
        _ => a.name,
      };

  static double _ease(double x) => x * x * (3 - 2 * x);

  /// [action] 의 [t](0~1) 자세. [breath](0~1 주기)로 숨쉬기를 더한다.
  static RigPose poseAt(RigAction action, WeaponKind? weapon, double t,
      {double breath = 0, bool reduced = false}) {
    final k = keys[keyOf(action, weapon)];
    RigPose p;
    if (k == null) {
      p = RigPose.stand;
    } else if (k.length == 1 || t <= k.first.$1) {
      p = k.first.$2;
    } else {
      p = k.last.$2;
      for (var i = 0; i + 1 < k.length; i++) {
        final (t0, a) = k[i];
        final (t1, b) = k[i + 1];
        if (t <= t1) {
          p = a.lerp(b, _ease(((t - t0) / (t1 - t0)).clamp(0.0, 1.0)));
          break;
        }
      }
    }
    if (reduced) p = p.damp(0.5);
    // 숨쉬기: 서기·이기기·지치기에서만 (몸이 살짝 오르내리고 머리·팔이 따라 흔들림)
    if (!reduced &&
        (action == RigAction.idle ||
            action == RigAction.victory ||
            action == RigAction.tired)) {
      final s = math.sin(breath * math.pi * 2);
      p = p.plus({
        'dy': s * (action == RigAction.tired ? 5 : 3),
        'head': s * 1.5,
        'arm_f_up': s * 2,
        'arm_b_up': -s * 2,
        'tail': s * 3,
        'W': s * 2,
      });
    }
    return p;
  }
}

class _RigImages {
  _RigImages(this.parts, this.weapon);
  final Map<String, ui.Image> parts;
  final ui.Image? weapon;
}

/// 부위 그림 (한 번 읽으면 계속 씀). 하나라도 없으면 null.
class HeroRigImages {
  HeroRigImages._();

  static final Map<String, Future<Map<String, ui.Image>?>> _parts = {};
  static final Map<WeaponKind, Future<ui.Image?>> _weapons = {};

  static Future<ui.Image?> _load(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, ui.Image>?> parts(HeroLook look) =>
      _parts[look.name] ??= () async {
        final out = <String, ui.Image>{};
        for (final name in HeroRigData.partImages) {
          final img = await _load(HeroRigData.partAsset(look, name));
          if (img == null) return null;
          out[name] = img;
        }
        for (final name in HeroRigData.extraImages) {
          final img = await _load(HeroRigData.partAsset(look, name));
          if (img != null) out[name] = img;
        }
        return out;
      }();

  static Future<ui.Image?> weapon(WeaponKind k) =>
      _weapons[k] ??= _load(HeroRigData.weaponAsset(k));
}

/// 각성자 부위 애니메이션. 그림이 없거나 아직 못 읽었으면 [fallback].
class HeroRig extends StatefulWidget {
  const HeroRig({
    super.key,
    required this.look,
    required this.action,
    required this.fallback,
    this.t = 0,
    this.breath = 0,
    this.weapon,
    this.reduced = false,
  });

  final HeroLook look;
  final RigAction action;

  /// 동작 진행 (0~1)
  final double t;

  /// 숨쉬기 주기 (0~1)
  final double breath;
  final WeaponKind? weapon;

  /// 「동작 줄이기」: 움직임 반만, 숨쉬기 없음
  final bool reduced;
  final Widget fallback;

  @override
  State<HeroRig> createState() => _HeroRigState();
}

class _HeroRigState extends State<HeroRig> {
  _RigImages? _images;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HeroRig old) {
    super.didUpdateWidget(old);
    if (old.look != widget.look || old.weapon != widget.weapon) _load();
  }

  Future<void> _load() async {
    final look = widget.look;
    final kind = widget.weapon;
    final parts = await HeroRigImages.parts(look);
    final weapon = kind == null ? null : await HeroRigImages.weapon(kind);
    if (!mounted || look != widget.look || kind != widget.weapon) return;
    setState(() {
      _failed = parts == null;
      _images = parts == null ? null : _RigImages(parts, weapon);
    });
  }

  @override
  Widget build(BuildContext context) {
    final img = _images;
    if (_failed || img == null) return widget.fallback;
    final pose = RigMotions.poseAt(widget.action, widget.weapon, widget.t,
        breath: widget.breath, reduced: widget.reduced);
    return Semantics(
      label: '각성자',
      image: true,
      child: CustomPaint(
        key: const Key('heroRig'),
        painter: HeroRigPainter(
            look: widget.look,
            images: img.parts,
            weapon: img.weapon,
            weaponKind: widget.weapon,
            pose: pose),
        size: Size.infinite,
      ),
    );
  }
}

/// 뼈대대로 부위를 그린다: 세계 = 부모 × 붙는 자리 이동 × 회전 × (−회전축) 이동
class HeroRigPainter extends CustomPainter {
  HeroRigPainter({
    this.look = HeroLook.male,
    required this.images,
    required this.pose,
    this.weapon,
    this.weaponKind,
  });

  final HeroLook look;
  final Map<String, ui.Image> images;
  final ui.Image? weapon;
  final WeaponKind? weaponKind;
  final RigPose pose;

  static const double _deg = math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    const f = HeroRigData.frame;
    // 틀을 상자 안에 맞추고 왼쪽 아래에 붙인다 (지금 통 그림과 같은 자리)
    final s = math.min(size.width / f.width, size.height / f.height);
    canvas.save();
    canvas.translate(0, size.height - f.height * s);
    canvas.scale(s);
    canvas.translate(-f.left, -f.top);

    final world = <String, _Aff>{};
    _Aff worldOf(String name) {
      final got = world[name];
      if (got != null) return got;
      final b = HeroRigData.byName[name]!;
      final _Aff base = b.parent == null
          ? _Aff.t(HeroRigData.root.dx + pose['dx'],
              HeroRigData.root.dy + pose['dy'])
          : worldOf(b.parent!) * _Aff.t(b.attach.dx, b.attach.dy);
      final m = base * _Aff.r(pose[name] * _deg) * _Aff.t(-b.pivot.dx, -b.pivot.dy);
      world[name] = m;
      return m;
    }

    final paint = Paint()..filterQuality = FilterQuality.medium;
    final raisedUp = pose['arm_f_up'] < HeroRigData.raisedArm;
    // 무기를 쥐고 있으면 쥔 손 그림 (무기 자리도 주먹 가운데로)
    final gripImg = weapon != null && weaponKind != null ? images['hand_grip'] : null;
    final g2 = HeroRigData.grip2[look]!;
    final handPivot = HeroRigData.byName['hand_f']!.pivot;
    final attach = gripImg == null
        ? HeroRigData.weaponAttach
        : handPivot + (g2.$2 - g2.$1);
    var order = HeroRigData.order;
    if (raisedUp) {
      // 팔을 들면 앞팔·무기·앞손을 머리 뒤로
      const front = ['arm_f_up', 'arm_f_fo', 'weapon', 'hand_f'];
      final rest = [for (final n in order) if (!front.contains(n)) n];
      final i = rest.indexOf('head');
      order = [...rest.sublist(0, i), ...front, ...rest.sublist(i)];
    }
    for (final n in order) {
      if (n == 'weapon') {
        final w = weapon, k = weaponKind;
        if (w == null || k == null) continue;
        final g = HeroRigData.grip[k]!;
        // 무기 각도 W 는 몸통 기준 각도: 손까지 돈 만큼 빼서 손에 붙인다
        final chain = pose['arm_f_up'] + pose['arm_f_fo'] + pose['hand_f'];
        final m = worldOf('hand_f') *
            _Aff.t(attach.dx, attach.dy) *
            _Aff.r((pose['W'] - chain) * _deg) *
            _Aff.s(HeroRigData.weaponScale) *
            _Aff.t(-g.dx, -g.dy);
        canvas.save();
        canvas.transform(m.storage);
        canvas.drawImage(w, Offset.zero, paint);
        canvas.restore();
        continue;
      }
      final b = HeroRigData.byName[n]!;
      if (n == 'hand_f' && gripImg != null) {
        // 손목을 같은 자리에 맞춰 쥔 손을 그린다
        final m = worldOf(n) *
            _Aff.t(handPivot.dx, handPivot.dy) *
            _Aff.t(-g2.$1.dx, -g2.$1.dy);
        canvas.save();
        canvas.transform(m.storage);
        canvas.drawImage(gripImg, Offset.zero, paint);
        canvas.restore();
        continue;
      }
      final raisedImg = images['arm_front_raised'];
      if (n == 'arm_f_up' && raisedUp && raisedImg != null) {
        // 들어 올린 앞팔: 어깨→팔꿈치 방향·길이를 원래 앞팔 위쪽과 맞춘다
        final r = HeroRigData.raised[look]!;
        final up = HeroRigData.byName['arm_f_fo']!.attach - b.pivot;
        final rv = r.$2 - r.$1;
        final rot = math.atan2(up.dy, up.dx) - math.atan2(rv.dy, rv.dx);
        final sc = (up.distance / rv.distance).clamp(0.7, 1.3);
        final m = worldOf(n) *
            _Aff.t(b.pivot.dx, b.pivot.dy) *
            _Aff.r(rot) *
            _Aff.s(sc) *
            _Aff.t(-r.$1.dx, -r.$1.dy);
        canvas.save();
        canvas.transform(m.storage);
        canvas.drawImage(raisedImg, Offset.zero, paint);
        canvas.restore();
        continue;
      }
      final img = images[b.image];
      if (img == null) continue;
      canvas.save();
      canvas.transform(worldOf(n).storage);
      canvas.drawImage(img, Offset.zero, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HeroRigPainter old) =>
      old.pose != pose ||
      old.weapon != weapon ||
      old.images != images ||
      old.look != look;
}

/// 2D 아핀 변환 [a b c; d e f] (뼈대 계산용)
class _Aff {
  const _Aff(this.a, this.b, this.c, this.d, this.e, this.f);
  final double a, b, c, d, e, f;

  factory _Aff.t(double x, double y) => _Aff(1, 0, x, 0, 1, y);
  factory _Aff.r(double rad) {
    final co = math.cos(rad), si = math.sin(rad);
    return _Aff(co, -si, 0, si, co, 0);
  }
  factory _Aff.s(double k) => _Aff(k, 0, 0, 0, k, 0);

  _Aff operator *(_Aff o) => _Aff(
        a * o.a + b * o.d, a * o.b + b * o.e, a * o.c + b * o.f + c,
        d * o.a + e * o.d, d * o.b + e * o.e, d * o.c + e * o.f + f);

  Float64List get storage => Float64List.fromList(
      [a, d, 0, 0, b, e, 0, 0, 0, 0, 1, 0, c, f, 0, 1]);
}

/// 상태 화면 서기(숨쉬기): 통 그림을 아주 조금 늘였다 줄인다.
/// 「동작 줄이기」·테스트에서는 멈춘 그림.
class BreathingHero extends StatefulWidget {
  const BreathingHero({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<BreathingHero> createState() => _BreathingHeroState();
}

class _BreathingHeroState extends State<BreathingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));

  /// 테스트(pumpAndSettle)가 끝나지 않는 일이 없게 멈춘다
  static bool disabledForTests =
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BreathingHero old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.enabled &&
        !disabledForTests &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on && !_c.isAnimating) {
      unawaited(_c.repeat());
    } else if (!on && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final s = math.sin(_c.value * math.pi * 2);
          return Transform(
            key: const Key('heroBreath'),
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 - s * 0.004, 1 + s * 0.012, 1),
            child: child,
          );
        },
      );
}
