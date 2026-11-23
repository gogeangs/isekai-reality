import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/models/pet_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../pets/farewell_screen.dart' show showHatchSheet;
import '../pets/pet_art.dart';
import '../town/bag_tab.dart' show showBagEntry, EggEntry;

/// 묶음 69 #285: 알 부화장 — 바탕 그림 위 둥지(뒤 · 알 · 앞) · 남은 시간 고리 · 알 움직임 · 빈 둥지
/// 그림(bg_hatchery · nest_back · nest_front)이 없으면 예전 모양(밤빛 판 · 짚 받침)
class HatcheryPanel extends StatelessWidget {
  const HatcheryPanel({super.key, required this.controller});

  final AppController controller;

  // 그림은 기획이 올리면 그대로 씀 (없으면 예전 모양)
  static const String _dir = 'assets/images/';
  static const String bg = '${_dir}bg_hatchery.webp';
  static const String nestBack = '${_dir}nest_back.webp';
  static const String nestFront = '${_dir}nest_front.webp';

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final warm = [for (final e in c.bagEggs) if (e.incubatedAt != null) e];
    final inBag = [for (final e in c.bagEggs) if (e.incubatedAt == null) e];
    final empty = c.canIncubateMore;
    // 묶음 73 #308: 판 높이는 바탕 그림 비율(1024:640), 둥지는 아래쪽 바닥 위(둥지 바닥이 판 높이 약 88%)
    return OrnatePanel(
      key: const Key('shelterNests'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1024 / 640,
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight;
            // 글 칸은 적어도 26 (아주 작은 판에서도 글자가 잘리지 않게)
            final band = math.max(h * 0.12, 26.0);
            final floor = h - band;
            final emptyLine = inBag.isEmpty ? '알을 얻으면 여기서 품어요' : '가방의 알을 품어 보세요';
            return Stack(children: [
              Positioned.fill(
                child: Image.asset(bg,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B1840))),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: _Pill(child: Text('알 부화장', key: const Key('hatcheryTitle'), style: AppText.title(15))),
              ),
              // 묶음 81 #372: 펫이 가득이면 알은 깨울 수 없음 (품기 · 팔기는 그대로)
              if (c.petsFull && c.bagEggs.isNotEmpty)
                const Positioned(
                  right: 10,
                  top: 12,
                  child: _Pill(
                    child: Text(PetsOps.petsFullLine,
                        key: Key('hatcheryPetsFull'),
                        style: TextStyle(color: AppColors.goldBright, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: floor - _Nest.pic,
                height: _Nest.pic + band,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, e) in warm.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _Nest(key: Key('nest_${e.id}'), controller: c, egg: e, band: band),
                    ],
                    if (empty) ...[
                      if (warm.isNotEmpty) const SizedBox(width: 10),
                      _EmptyNest(
                        key: const Key('nestEmpty'),
                        band: band,
                        // 묶음 76 #316: 둥지 하나뿐이면 안내 글은 판 가운데 아래(넓게), 여러 개면 그 둥지 아래 두 줄까지
                        line: warm.isEmpty ? null : emptyLine,
                        onTap: inBag.isEmpty ? null : () => _pickEgg(context, c, inBag),
                      ),
                    ],
                  ],
                ),
              ),
              if (empty && warm.isEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  top: floor,
                  height: band,
                  child: Center(
                    child: _Pill(
                      child: Text(emptyLine,
                          key: const Key('nestEmptyLine'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ),
    );
  }

  static Future<void> _pickEgg(BuildContext context, AppController c, List<PetEgg> eggs) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (s) => SafeArea(
        child: Padding(
          key: const Key('eggPick'),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('품을 알 고르기', style: AppText.title(17)),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final e in eggs)
                GestureDetector(
                  key: Key('eggPick_${e.id}'),
                  onTap: () => Navigator.pop(s, e.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2152),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: EggArt(size: 56, grade: e.grade),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (id == null) return;
    final ok = await c.incubateEgg(id);
    if (context.mounted && ok) showTopNotice(context, '알을 둥지에 품었어요', icon: Icons.egg_rounded);
  }
}

/// 둥지 하나 (뒤 · 알 · 앞 겹침, 아래에 금빛 고리)
class _Nest extends StatefulWidget {
  const _Nest({super.key, required this.controller, required this.egg, required this.band});
  final AppController controller;
  final PetEgg egg;

  /// 둥지 아래 글 칸 높이 (판 아래 12%)
  final double band;

  /// 둥지 그림 칸 높이
  static const double pic = 116;

  @override
  State<_Nest> createState() => _NestState();
}

class _NestState extends State<_Nest> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final e = widget.egg;
    final ready = c.eggReady(e);
    final total = PetRules.hatchTime.inSeconds;
    final left = ready ? Duration.zero : e.incubatedAt!.add(PetRules.hatchTime).difference(c.now);
    final done = ready ? 1.0 : (1 - left.inSeconds / total).clamp(0.0, 1.0);
    final soon = !ready && left.inMinutes < 60;
    return GestureDetector(
      onTap: () => ready ? showHatchSheet(context, c, e) : showBagEntry(context, c, EggEntry(e)),
      child: SizedBox(
        width: 136,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 126,
            height: _Nest.pic,
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) {
                final t = _a.value;
                // 품는 중: 몇 초마다 살짝 흔들림 (남은 시간이 적을수록 더 자주 · 더 크게)
                // 다 되면: 통통 튀고 반짝임
                double angle = 0, lift = 0;
                if (ready) {
                  lift = -(math.sin(t * math.pi * 6).abs()) * 8;
                } else {
                  final every = done > 0.85 ? 2 : (done > 0.5 ? 3 : 4); // 4초 안에 흔들리는 번수 (가까울수록 자주)
                  final ph = (t * every) % 1;
                  final amp = 0.06 + 0.12 * done;
                  if (ph < 0.18) angle = math.sin(ph / 0.18 * math.pi * 3) * amp;
                }
                return Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
                  // 묶음 76 #316: 둥지 그림의 실제 바닥(칸 높이 80%)에 붙임
                  const Positioned(bottom: 13, child: _NestShadow()),
                  if (ready)
                    Positioned(
                      bottom: 24,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.goldBright.withValues(alpha: 0.35 + 0.25 * math.sin(t * math.pi * 4).abs()),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  // 둥지 뒤 (그림이 없으면 짚 받침)
                  Positioned(
                    bottom: 0,
                    child: Image.asset(HatcheryPanel.nestBack,
                        width: 110,
                        height: 110,
                        errorBuilder: (_, __, ___) => const _StrawNest()),
                  ),
                  Positioned(
                    // 묶음 72 #285: 알 아랫선을 둥지 그림 높이의 78%에 (반쯤 묻히고 양옆 테가 감쌈)
                    bottom: 110 * (1 - 0.78) - lift,
                    child: Transform.rotate(
                      angle: angle,
                      alignment: Alignment.bottomCenter,
                      child: EggArt(size: 62, glowing: true, grade: e.grade),
                    ),
                  ),
                  // 둥지 앞 (알이 반쯤 묻히게)
                  Positioned(
                    bottom: 0,
                    child: Image.asset(HatcheryPanel.nestFront,
                        width: 110, height: 110, errorBuilder: (_, __, ___) => const SizedBox(width: 110, height: 1)),
                  ),
                ]);
              },
            ),
          ),
          SizedBox(
            height: widget.band,
            child: Center(
              child: ready
                  ? SizedBox(
                      height: math.min(30, widget.band - 2),
                      child: GoldButton(
                        key: Key('nestWake_${e.id}'),
                        label: '깨우기',
                        height: math.min(30, widget.band - 2),
                        fontSize: 13,
                        onPressed: () => showHatchSheet(context, c, e),
                      ),
                    )
                  : _Pill(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CustomPaint(painter: _Ring(done)),
                        ),
                        const SizedBox(width: 5),
                        Text(soon ? '곧 깨어나요!' : _left(left),
                            key: Key('nestLeft_${e.id}'),
                            style: TextStyle(
                                color: soon ? AppColors.goldBright : AppColors.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  static String _left(Duration d) {
    final m = (d.inSeconds + 59) ~/ 60;
    if (m >= 60) return '${m ~/ 60}시간 ${m % 60}분';
    return '$m분';
  }
}

/// 남은 시간 고리 (금빛이 차오름)
class _Ring extends CustomPainter {
  _Ring(this.done);
  final double done;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawArc(r, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x55FFFFFF));
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * done, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.goldBright);
  }

  @override
  bool shouldRepaint(_Ring old) => old.done != done;
}

/// 그림이 없을 때 짚 받침 (예전 모양)
class _StrawNest extends StatelessWidget {
  const _StrawNest();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 110,
        height: 110,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 96,
            height: 34,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const RadialGradient(colors: [Color(0xFF8A6A3A), Color(0xFF5A4022)]),
              border: Border.all(color: const Color(0xFFC9A05A), width: 2),
            ),
          ),
        ),
      );
}

/// 둥지 밑 옅은 타원 그림자 (바닥에 놓인 느낌)
class _NestShadow extends StatelessWidget {
  const _NestShadow();

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.elliptical(48, 9)),
          gradient: RadialGradient(colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: 0),
          ]),
        ),
      );
}

/// 어두운 반투명 알약 바탕 (덩굴 · 벽 위에서도 글자가 읽히게)
class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xB30B0D26),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: child,
      );
}

/// 빈 둥지 하나 (누르면 가방의 알 고르기). 묶음 73 #308: 둥지는 불투명, 비었다는 표시는 + · 안내 글로만
class _EmptyNest extends StatelessWidget {
  const _EmptyNest({super.key, required this.line, required this.band, this.onTap});

  /// 둥지 아래 글 (null 이면 판이 대신 보여 줌)
  final String? line;
  final double band;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 136,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 126,
              height: _Nest.pic,
              child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
                // 묶음 76 #316: 둥지 그림의 실제 바닥(칸 높이 80%)에 붙임
                  const Positioned(bottom: 13, child: _NestShadow()),
                Positioned(
                  bottom: 0,
                  child: Image.asset(HatcheryPanel.nestBack,
                      key: const Key('nestEmptyBack'),
                      width: 110, height: 110, errorBuilder: (_, __, ___) => const _StrawNest()),
                ),
                Positioned(
                  bottom: 0,
                  child: Image.asset(HatcheryPanel.nestFront,
                      width: 110, height: 110, errorBuilder: (_, __, ___) => const SizedBox(width: 110, height: 1)),
                ),
                if (onTap != null)
                  const Positioned(
                    bottom: 40,
                    child: Icon(Icons.add_circle_rounded, color: AppColors.goldBright, size: 30),
                  ),
              ]),
            ),
            SizedBox(
              height: band,
              child: line == null
                  ? null
                  : Center(
                      child: _Pill(
                        child: Text(line!,
                            key: const Key('nestEmptyLine'),
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.1)),
                      ),
                    ),
            ),
          ]),
        ),
      );
}
