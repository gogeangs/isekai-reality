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
    final warm = [for (final e in c.pets.eggs) if (e.incubatedAt != null) e];
    final inBag = [for (final e in c.pets.eggs) if (e.incubatedAt == null) e];
    final empty = c.canIncubateMore;
    return OrnatePanel(
      key: const Key('shelterNests'),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          Positioned.fill(
            child: Image.asset(bg,
                fit: BoxFit.cover, alignment: Alignment.center, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          // 아래쪽만 살짝 어둡게 (글자가 잘 보이게)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B0D26), Color(0x000B0D26), Color(0x990B0D26)],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('알 부화장', style: AppText.title(17)),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final e in warm) _Nest(key: Key('nest_${e.id}'), controller: c, egg: e),
                  if (empty)
                    _EmptyNest(
                      key: const Key('nestEmpty'),
                      line: inBag.isEmpty ? '알을 얻으면 여기서 품어요' : '가방의 알을 품어 보세요',
                      onTap: inBag.isEmpty ? null : () => _pickEgg(context, c, inBag),
                    ),
                ],
              ),
            ]),
          ),
        ]),
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
                    child: const EggArt(size: 56),
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
  const _Nest({super.key, required this.controller, required this.egg});
  final AppController controller;
  final PetEgg egg;

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
        width: 126,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 126,
            height: 116,
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
                    bottom: 30 - lift.abs() * 0 + (-lift),
                    child: Transform.rotate(
                      angle: angle,
                      alignment: Alignment.bottomCenter,
                      child: EggArt(size: 62, glowing: true),
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
          const SizedBox(height: 4),
          if (ready)
            GoldButton(
              key: Key('nestWake_${e.id}'),
              label: '깨우기',
              height: 36,
              fontSize: 15,
              onPressed: () => showHatchSheet(context, c, e),
            )
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CustomPaint(painter: _Ring(done)),
              ),
              const SizedBox(width: 6),
              Text(soon ? '곧 깨어나요!' : _left(left),
                  key: Key('nestLeft_${e.id}'),
                  style: TextStyle(
                      color: soon ? AppColors.goldBright : AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
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

/// 빈 둥지 하나 (누르면 가방의 알 고르기)
class _EmptyNest extends StatelessWidget {
  const _EmptyNest({super.key, required this.line, this.onTap});
  final String line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 126,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 126,
              height: 116,
              child: Stack(alignment: Alignment.bottomCenter, children: [
                Positioned(
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.8,
                    child: Image.asset(HatcheryPanel.nestBack,
                        width: 110, height: 110, errorBuilder: (_, __, ___) => const _StrawNest()),
                  ),
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
            const SizedBox(height: 4),
            KText(line,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
