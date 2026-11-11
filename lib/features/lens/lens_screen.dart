import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../data/device/device_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'camera_sticker_engine.dart';
import 'lens_output.dart';
import 'photo_frame.dart';
import 'race_filter_engine.dart';
import '../../theme/top_notice.dart';

/// 마법 돋보기 「감정」 (11-11 #60): 카메라 → 감정 연출 → 종족 필터 → 사진(틀) → 저장·공유.
/// 얼굴 인식은 휴대폰 안에서만 하고, 게임은 사진을 남기지 않는다.
class LensScreen extends StatefulWidget {
  const LensScreen({super.key, required this.controller});

  final AppController controller;

  /// 필터 엔진을 만드는 곳 (2차 SDK로 바꾸거나 테스트에서 예시 엔진을 끼운다)
  static RaceFilterEngine Function() engineFactory = CameraStickerEngine.new;

  @override
  State<LensScreen> createState() => _LensScreenState();
}

enum _Phase { loading, error, aim, appraising, reveal, filter, shot }

class _LensScreenState extends State<LensScreen> with TickerProviderStateMixin {
  late final RaceFilterEngine _engine = LensScreen.engineFactory();
  _Phase _phase = _Phase.loading;
  String? _error;
  List<Race>? _races;
  AppraiseResult? _result;
  Uint8List? _png;
  bool _working = false;
  final _random = math.Random();
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: LensRules.appraiseTime);

  AppController get c => widget.controller;
  int get _lenses => c.bagCount(ShopItem.raceLens);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final err = await _engine.start();
    if (!mounted) return;
    setState(() {
      _error = err;
      _phase = err == null ? _Phase.aim : _Phase.error;
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    unawaited(_engine.dispose());
    unawaited(LensOutput.cleanUp());
    super.dispose();
  }

  void _snack(String s) {
    showTopNotice(context, s);
  }

  Future<void> _appraise() async {
    final n = math.min(_engine.faces.value.length, LensRules.maxFaces);
    if (n == 0) {
      _snack('얼굴이 보이지 않아요. 얼굴을 화면 가운데에 비춰 주세요.');
      return;
    }
    if (_lenses <= 0) {
      _snack('마법 돋보기가 없어요. 잡화상에서 살 수 있어요.');
      return;
    }
    setState(() => _phase = _Phase.appraising);
    await _spin.forward(from: 0);
    final races = LensRules.rollFaces(_random, n);
    final r = await c.appraise(races);
    if (!mounted) return;
    if (r == null) {
      setState(() => _phase = _Phase.aim);
      _snack('마법 돋보기가 없어요.');
      return;
    }
    setState(() {
      _races = races;
      _result = r;
      _phase = _Phase.reveal;
    });
  }

  Future<void> _shoot() async {
    final races = _races;
    if (races == null || _working) return;
    setState(() => _working = true);
    final photo = await _engine.capture(races);
    Uint8List? png;
    if (photo != null) {
      png = await PhotoFrame.compose(photo, races);
      photo.dispose();
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      if (png != null) {
        _png = png;
        _phase = _Phase.shot;
      }
    });
    if (png == null) _snack('사진을 찍지 못했어요. 다시 해 볼까요?');
  }

  Future<void> _save() async {
    final png = _png;
    if (png == null || _working) return;
    setState(() => _working = true);
    final err = await LensOutput.saver(png);
    if (!mounted) return;
    setState(() => _working = false);
    _snack(err ?? '사진 앨범에 저장했어요!');
  }

  Future<void> _share(BuildContext button) async {
    final png = _png;
    if (png == null || _working) return;
    final box = button.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _working = true);
    try {
      await LensOutput.sharer(
          png,
          '마법 돋보기로 감정해 보니 ${PhotoFrame.raceLine(_races ?? const [])}! '
          '#이세계가현실이라면',
          origin);
    } catch (_) {
      if (mounted) _snack('공유하지 못했어요.');
    }
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D26),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(children: [
            _topBar(context),
            Expanded(child: _view()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: _bottom(context),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
        child: Row(children: [
          IconButton(
            tooltip: '돌아가기',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          ),
          Text('마법 돋보기', style: AppText.title(20)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2250),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/images/icon_lens.png',
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) => const Icon(Icons.search_rounded,
                      size: 16, color: AppColors.goldBright)),
              const SizedBox(width: 4),
              Text('$_lenses',
                  key: const Key('lensCount'),
                  style: const TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (_engine.canSwitchCamera &&
              _phase != _Phase.shot &&
              _phase != _Phase.appraising)
            IconButton(
              tooltip: '카메라 바꾸기',
              onPressed: () async {
                await _engine.switchCamera();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.cameraswitch_rounded,
                  color: AppColors.goldBright),
            ),
        ]),
      );

  Widget _view() {
    if (_phase == _Phase.loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.goldBright));
    }
    if (_phase == _Phase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            KText(_error ?? '카메라를 켜지 못했어요.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 15)),
            const SizedBox(height: 14),
            FrameButton(
                label: '휴대폰 설정 열기',
                onPressed: () => DeviceLinks.openAppSettings()),
          ]),
        ),
      );
    }
    if (_phase == _Phase.shot && _png != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_png!, key: const Key('lensPhoto')),
          ),
        ),
      );
    }
    final showFilter = _phase == _Phase.reveal || _phase == _Phase.filter;
    return Center(
      child: AspectRatio(
        aspectRatio: _engine.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            _engine.preview(showFilter ? _races : null),
            if (_phase == _Phase.aim)
              ValueListenableBuilder<List<FaceSpot>>(
                valueListenable: _engine.faces,
                builder: (_, faces, __) =>
                    CustomPaint(painter: _AimPainter(faces)),
              ),
            if (_phase == _Phase.appraising)
              AnimatedBuilder(
                animation: _spin,
                builder: (_, __) => CustomPaint(
                  painter: _AppraisePainter(_spin.value, _engine.faces.value),
                ),
              ),
            if (_phase == _Phase.reveal && _result != null)
              _RevealPanel(
                  result: _result!,
                  onClose: () => setState(() => _phase = _Phase.filter)),
          ]),
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
      case _Phase.error:
        return const SizedBox(height: 8);
      case _Phase.aim:
        return ValueListenableBuilder<List<FaceSpot>>(
          valueListenable: _engine.faces,
          builder: (_, faces, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KText(
                  _lenses <= 0
                      ? '마법 돋보기가 없어요. 잡화상에서 하루 ${LensRules.perDay}개까지 살 수 있어요.'
                      : faces.isEmpty
                          ? '얼굴을 비추면 숨은 이세계 종족을 감정해요.'
                          : '얼굴 ${faces.length}명을 찾았어요. 감정해 볼까요?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                  '얼굴 인식은 휴대폰 안에서만 해요 · 오늘 보상 남은 횟수 ${c.lensRewardsLeft}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11.5)),
              const SizedBox(height: 10),
              GoldButton(
                key: const Key('appraise'),
                label: '감정하기 (돋보기 1개)',
                onPressed:
                    faces.isNotEmpty && _lenses > 0 ? _appraise : null,
              ),
            ],
          ),
        );
      case _Phase.appraising:
        return Text('감정 중…',
            textAlign: TextAlign.center, style: AppText.title(20));
      case _Phase.reveal:
        return GoldButton(
          key: const Key('lensToFilter'),
          label: '변신한 모습 보기',
          onPressed: () => setState(() => _phase = _Phase.filter),
        );
      case _Phase.filter:
        return Row(children: [
          Expanded(
            child: FrameButton(
              label: '새 감정',
              height: 48,
              onPressed: _lenses > 0
                  ? () => setState(() {
                        _races = null;
                        _result = null;
                        _phase = _Phase.aim;
                      })
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          _Shutter(busy: _working, onTap: _shoot),
          const SizedBox(width: 12),
          Expanded(
            child: Text(PhotoFrame.raceLine(_races ?? const []),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppText.title(15)),
          ),
        ]);
      case _Phase.shot:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: GoldButton(
                key: const Key('lensSave'),
                label: '앨범에 저장',
                height: 46,
                onPressed: _working ? null : _save,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Builder(
                builder: (b) => FrameButton(
                  label: '공유하기',
                  height: 46,
                  onPressed: _working ? null : () => _share(b),
                ),
              ),
            ),
          ]),
          TextButton(
            onPressed: () => setState(() {
              _png = null;
              _phase = _Phase.filter;
            }),
            child: const Text('다시 찍기',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          const Text('게임 안에는 사진을 남기지 않아요. 저장하거나 공유한 사진만 남아요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]);
    }
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('lensShutter'),
        onTap: busy ? null : onTap,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldBright, width: 4),
          ),
          padding: const EdgeInsets.all(5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: busy ? AppColors.textMuted : const Color(0xFFFFF3C4),
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: AppColors.night))
                : const Icon(Icons.photo_camera_rounded,
                    color: AppColors.night, size: 30),
          ),
        ),
      );
}

/// 감정 결과 (얼굴마다 종족 + 보상)
class _RevealPanel extends StatelessWidget {
  const _RevealPanel({required this.result, required this.onClose});

  final AppraiseResult result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final rewards = <String>[
      if (r.firsts.isNotEmpty)
        '처음 감정한 종족! 도감 「종족」에 남았어요 · 경험치 +${r.exp}',
      if (r.material != null)
        '돋보기에 ${Materials.info(r.material!).name} 1개가 걸려 나왔어요',
      if (r.note) '레시피 쪽지 1장을 주웠어요',
    ];
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0x99080A20),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Transform.scale(scale: t, child: child),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: OrnatePanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('✦ 감정 결과 ✦',
                        textAlign: TextAlign.center,
                        style: AppText.title(16, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    for (final (i, race) in r.races.indexed) ...[
                      Text(
                          r.races.length > 1
                              ? '${i + 1}번째 사람 · ${LensRules.info(race).name}'
                              : LensRules.info(race).name,
                          textAlign: TextAlign.center,
                          style: AppText.title(r.races.length > 1 ? 19 : 26,
                              color: Color(LensRules.info(race).color))),
                      KText(LensRules.info(race).line,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 13.5)),
                      const SizedBox(height: 8),
                    ],
                    for (final line in rewards)
                      KText('· $line',
                          style: const TextStyle(
                              color: AppColors.goldBright, fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 얼굴을 찾았다는 금빛 테두리
class _AimPainter extends CustomPainter {
  _AimPainter(this.faces);

  final List<FaceSpot> faces;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.goldBright.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final f in faces) {
      final r = Rect.fromLTRB(f.box.left * size.width, f.box.top * size.height,
          f.box.right * size.width, f.box.bottom * size.height);
      final k = r.width * 0.22;
      for (final (corner, dx, dy) in [
        (r.topLeft, 1.0, 1.0),
        (r.topRight, -1.0, 1.0),
        (r.bottomLeft, 1.0, -1.0),
        (r.bottomRight, -1.0, -1.0),
      ]) {
        canvas.drawLine(corner, corner + Offset(dx * k, 0), p);
        canvas.drawLine(corner, corner + Offset(0, dy * k), p);
      }
    }
  }

  @override
  bool shouldRepaint(_AimPainter old) => old.faces != faces;
}

/// 감정 연출: 얼굴마다 돌아가는 마법진 + 위아래로 훑는 빛
class _AppraisePainter extends CustomPainter {
  _AppraisePainter(this.t, this.faces);

  final double t;
  final List<FaceSpot> faces;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFF0B0D26).withValues(alpha: 0.25 * t));
    const gold = AppColors.goldBright;
    for (final f in faces) {
      final c = Offset(f.box.center.dx * size.width, f.box.center.dy * size.height);
      final rad = f.box.width * size.width * 0.78;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * math.pi * 2);
      final ring = Paint()
        ..color = gold.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset.zero, rad, ring);
      canvas.drawCircle(Offset.zero, rad * 0.86, ring..strokeWidth = 1.2);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final o = Offset(math.cos(a) * rad * 0.93, math.sin(a) * rad * 0.93);
        canvas.drawCircle(o, 4, Paint()..color = gold);
      }
      final tri = Path();
      for (var i = 0; i < 3; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / 3;
        final o = Offset(math.cos(a) * rad * 0.86, math.sin(a) * rad * 0.86);
        i == 0 ? tri.moveTo(o.dx, o.dy) : tri.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(tri..close(), ring..strokeWidth = 1);
      canvas.restore();
    }
    // 훑는 빛
    final y = size.height * (0.5 + 0.5 * math.sin(t * math.pi * 3));
    final band = Rect.fromLTWH(0, y - 30, size.width, 60);
    canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gold.withValues(alpha: 0),
              gold.withValues(alpha: 0.35),
              gold.withValues(alpha: 0),
            ],
          ).createShader(band));
  }

  @override
  bool shouldRepaint(_AppraisePainter old) => true;
}

/// 가방에서 마법 돋보기를 쓴다 (감정 화면 열기)
Future<void> openLens(NavigatorState nav, AppController c) =>
    nav.push(MaterialPageRoute<void>(builder: (_) => LensScreen(controller: c)));

/// 종족 이름 + 조사 (도감 등에서 쓴다)
String raceWithJosa(Race r, String pair) => josa(LensRules.info(r).name, pair);
