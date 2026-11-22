import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart' show HeroSprite, HeroPose, MonsterPicture;
import '../bulssi/spirit_art.dart' show SpiritMood;
import '../bulssi/bulssi_bubble.dart' show BulssiLine;
import '../jobs/skill_icon.dart' show SkillArt;
import '../pets/pet_art.dart';

/// 묶음 82 #394: 잿빛 틈 분신 턴제 화면.
/// 위: 분신 이름 · HP 막대 · 감정 게이지 5칸 · 기억 3칸 → 무대(분신 · 말풍선 · 주인공 · 펫) →
/// 한 줄 소식 → 내 HP · MP → 명령 6칸(3 × 2). 마주하기는 화면 가운데 「왕의 기억」 글판.
class AshTurnView extends StatefulWidget {
  const AshTurnView({
    super.key,
    required this.controller,
    required this.turn,
    required this.background,
    required this.onFinished,
    this.fast = false,
    this.stepDelay = const Duration(milliseconds: 520),
  });

  final AppController controller;
  final AshTurn turn;
  final String background;
  final VoidCallback onFinished;

  /// 빠른 전투: 연출을 짧게
  final bool fast;
  final Duration stepDelay;

  @override
  State<AshTurnView> createState() => _AshTurnViewState();
}

class _AshTurnViewState extends State<AshTurnView> {
  AshTurn get t => widget.turn;
  AppController get c => widget.controller;

  bool _busy = false;
  String _log = '';
  String? _hint;

  // 연출
  bool _heroLunge = false;
  bool _heroHurt = false;
  bool _petLunge = false;
  bool _foeFlash = false;
  bool _shake = false;
  bool _redFlash = false;
  bool _guardFx = false;
  final List<_Float> _floats = [];
  int _floatId = 0;

  /// 지금 보여 주는 왕의 기억 조각 (null 이면 없음)
  int? _memory;
  Completer<void>? _memoryDone;

  Duration get _d => widget.fast ? Duration(milliseconds: widget.stepDelay.inMilliseconds ~/ 2) : widget.stepDelay;

  @override
  void initState() {
    super.initState();
    _log = '${Act2Rules.info(t.avatar).name}이(가) 나타났어요. 내 차례예요.';
    _hint = '${t.info.gauge} 칸이 다 차면 크게 공격해! 「마주하기」로 마음을 달래 봐.';
  }

  Future<void> _wait([double k = 1]) => Future<void>.delayed(Duration(milliseconds: (_d.inMilliseconds * k).round()));

  void _float(String text, {required bool onFoe, Color color = Colors.white, bool big = false}) {
    final id = _floatId++;
    setState(() => _floats.add(_Float(id, text, onFoe, color, big)));
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
    });
  }

  Future<void> _go(AshCmd cmd) async {
    if (_busy || !t.can(cmd)) return;
    setState(() {
      _busy = true;
      _hint = null;
    });
    // 직업 스킬은 직업 MP를 바로 씀 (가방 · 동전 등 스킬마다 따로 드는 것 포함)
    final skill = t.skillOf(cmd);
    if (skill != null) {
      final s = JobRules.parseSkill(skill.key);
      if (s != null) await c.payBattleSkill(s);
    }
    final events = t.act(cmd);
    for (final e in events) {
      if (!mounted) return;
      await _show(e);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (t.isOver) {
      await _wait(1.4);
      if (mounted) widget.onFinished();
    }
  }

  Future<void> _show(AshEvent e) async {
    switch (e.kind) {
      case AshEventKind.heroHit:
        setState(() => _heroLunge = true);
        await _wait(0.35);
        setState(() {
          _foeFlash = true;
          _shake = e.big;
          _log = e.text.isEmpty ? '공격!' : e.text;
        });
        _float('${e.value}', onFoe: true, big: e.big);
        await _wait(0.3);
        setState(() {
          _foeFlash = false;
          _shake = false;
          _heroLunge = false;
        });
      case AshEventKind.heroMiss:
        setState(() => _heroLunge = true);
        await _wait(0.35);
        _float('빗나감', onFoe: true, color: const Color(0xFF9FC6FF));
        setState(() {
          _heroLunge = false;
          _log = e.text;
        });
      case AshEventKind.heroGuard:
      case AshEventKind.heroWall:
        setState(() {
          _guardFx = true;
          _log = e.text;
        });
      case AshEventKind.heroPotion:
        _float('+${e.value}', onFoe: false, color: const Color(0xFF8DFFA8));
        setState(() => _log = e.text);
      case AshEventKind.face:
        setState(() => _log = e.text);
        if (e.memory >= 0) {
          _memoryDone = Completer<void>();
          setState(() => _memory = e.memory);
          await _memoryDone!.future;
          if (!mounted) return;
          setState(() => _memory = null);
        }
      case AshEventKind.petHit:
        setState(() => _petLunge = true);
        await _wait(0.3);
        setState(() => _foeFlash = true);
        _float('${e.value}', onFoe: true);
        await _wait(0.25);
        setState(() {
          _foeFlash = false;
          _petLunge = false;
        });
      case AshEventKind.petAway:
        setState(() => _log = e.text);
      case AshEventKind.foeSpecial:
        setState(() {
          _redFlash = true;
          _shake = e.big;
          _log = e.text;
        });
        if (e.value > 0) {
          setState(() => _heroHurt = true);
          _float('-${e.value}', onFoe: false, color: const Color(0xFFFF8A8A), big: e.big);
        }
        await _wait(0.5);
        setState(() {
          _redFlash = false;
          _shake = false;
          _heroHurt = false;
        });
      case AshEventKind.foeHit:
        await _wait(0.3);
        setState(() {
          _heroHurt = e.value > 0;
          if (e.value == 0) _log = e.text;
        });
        _float(e.value > 0 ? '-${e.value}' : '피함', onFoe: false, color: const Color(0xFFFF8A8A));
        await _wait(0.3);
        setState(() => _heroHurt = false);
      case AshEventKind.foeHeal:
        _float('+${e.value}', onFoe: true, color: const Color(0xFF8DFFA8));
      case AshEventKind.warn:
        setState(() {
          _log = e.text;
          _hint = t.info.hint;
        });
      case AshEventKind.foeDown:
        setState(() => _log = '${Act2Rules.info(t.avatar).name}이(가) 쓰러졌어요!');
      case AshEventKind.heroDown:
        setState(() => _log = '쓰러졌어요…');
    }
    await _wait(0.5);
    if (mounted && !t.guarding && t.wall <= 0) setState(() => _guardFx = false);
  }

  @override
  Widget build(BuildContext context) {
    final info = t.info;
    final gaugeColor = Color(info.color);
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _top(info, gaugeColor),
        const SizedBox(height: 6),
        Expanded(child: _stage(info)),
        const SizedBox(height: 4),
        Container(
          key: const Key('ashTurnLog'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minHeight: 30),
          decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
          child: Text(_log, maxLines: 2, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        ),
        const SizedBox(height: 6),
        _meBars(),
        const SizedBox(height: 8),
        _commands(info),
      ]),
      if (_memory != null) Positioned.fill(child: _memoryPanel(info, _memory!)),
    ]);
  }

  Widget _top(AshTurnInfo info, Color gc) {
    final ratio = t.foeMax <= 0 ? 0.0 : t.foeHp / t.foeMax;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(Act2Rules.info(t.avatar).name, style: AppText.title(17, color: AppColors.goldBright)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          key: const Key('ashTurnFoeHp'),
          value: ratio.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: const Color(0x66000000),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFE25B5B)),
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Text(info.gauge, style: TextStyle(color: gc, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        Expanded(
          child: Row(key: const Key('ashGauge'), children: [
            for (var i = 0; i < AshTurnRules.gaugeMax; i++)
              Expanded(
                child: AnimatedContainer(
                  key: Key('ashGauge_$i${i < t.gauge ? '_on' : ''}'),
                  duration: const Duration(milliseconds: 300),
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: i < t.gauge ? gc : const Color(0xFF3A2240),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: i < t.gauge && t.specialNext ? [BoxShadow(color: gc, blurRadius: 6)] : null,
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        const Text('기억', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 4),
        for (var i = 0; i < AshTurnRules.memoryCount; i++)
          Container(
            key: Key('ashMem_$i${i < t.memoriesSeen ? '_got' : ''}'),
            width: 15,
            height: 15,
            margin: const EdgeInsets.only(left: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < t.memoriesSeen ? AppColors.gold : Colors.transparent,
              border: Border.all(color: AppColors.gold),
            ),
            child: Text('${i + 1}',
                style: TextStyle(
                    fontSize: 9, color: i < t.memoriesSeen ? const Color(0xFF2A1A00) : AppColors.gold, height: 1.1)),
          ),
      ]),
    ]);
  }

  Widget _stage(AshTurnInfo info) {
    final a = Act2Rules.info(t.avatar);
    final pet = c.companionPet;
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      final w = box.maxWidth;
      final foeSize = math.min(w * 0.55, h * 0.62);
      return AnimatedSlide(
        offset: _shake ? const Offset(0.012, 0) : Offset.zero,
        duration: const Duration(milliseconds: 60),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(widget.background,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B1840))),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA0D0B22)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            // 분신
            Positioned(
              right: w * 0.06,
              top: h * 0.04,
              width: foeSize,
              height: foeSize,
              child: AnimatedOpacity(
                opacity: t.won ? 0.35 : 1,
                duration: const Duration(milliseconds: 400),
                child: ColorFiltered(
                  colorFilter: _foeFlash
                      ? const ColorFilter.mode(Color(0xCCFFFFFF), BlendMode.srcATop)
                      : const ColorFilter.mode(Color(0x00000000), BlendMode.srcATop),
                  child: MonsterPicture(key: const Key('ashTurnFoe'), monster: a.monster, size: foeSize),
                ),
              ),
            ),
            // 말풍선 (왕의 목소리, 예고 땐 붉게)
            Positioned(
              left: 10,
              top: 10,
              width: math.min(190, w * 0.5),
              child: AnimatedContainer(
                key: Key(t.sayWarn ? 'ashSayWarn' : 'ashSay'),
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                decoration: BoxDecoration(
                  color: t.sayWarn ? const Color(0xDD5A1A0A) : const Color(0xCC1C1A44),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.sayWarn ? const Color(0xFFFF5A1F) : AppColors.gold, width: 1.2),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  KText(t.say,
                      style: AppText.title(13, color: t.sayWarn ? const Color(0xFFFFD7B8) : AppColors.text)
                          .copyWith(height: 1.4)),
                  if (t.specialNext) ...[
                    const SizedBox(height: 3),
                    Text('다음 턴: ${info.special}',
                        key: const Key('ashWarnNext'),
                        style: const TextStyle(color: Color(0xFFFFB27A), fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ]),
              ),
            ),
            // 주인공
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              left: _heroLunge ? w * 0.28 : w * 0.04,
              bottom: _heroLunge ? h * 0.12 : 6,
              width: math.min(130, w * 0.3),
              height: math.min(170, h * 0.5),
              child: AnimatedSlide(
                offset: _heroHurt ? const Offset(-0.06, 0) : Offset.zero,
                duration: const Duration(milliseconds: 80),
                child: Stack(fit: StackFit.expand, children: [
                  HeroSprite(
                      look: c.profile.look,
                      pose: _heroLunge ? HeroPose.attack : HeroPose.idle,
                      t: _heroLunge ? 0.6 : 0,
                      job: c.heroJobArt),
                  if (_guardFx || t.wall > 0)
                    Opacity(
                      opacity: 0.8,
                      child: Image.asset('assets/images/fx_guard.webp',
                          key: const Key('ashGuardFx'), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                ]),
              ),
            ),
            // 펫
            if (pet != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _petLunge ? w * 0.46 : w * 0.33,
                bottom: _petLunge ? h * 0.22 : 8,
                width: 60,
                height: 60,
                child: AnimatedOpacity(
                  opacity: t.petAway > 0 ? 0.3 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: PetArt.of(pet, key: const Key('ashTurnPet'), size: 60),
                ),
              ),
            // 숫자
            for (final f in _floats)
              _FloatNum(
                key: ValueKey('float${f.id}'),
                f: f,
                left: f.onFoe ? w * 0.6 : w * 0.12,
                top: f.onFoe ? h * 0.25 : h * 0.5,
              ),
            if (_redFlash)
              const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0x55FF3A1F)))),
            if (_hint != null)
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.95,
                    child: BulssiLine(
                        key: const Key('ashHint'),
                        line: _hint!,
                        mood: t.specialNext ? SpiritMood.worried : SpiritMood.normal),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }

  Widget _meBars() {
    Widget bar(String label, int v, int max, Color color, Key key) => Row(children: [
          SizedBox(width: 30, child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                key: key,
                value: max <= 0 ? 0 : (v / max).clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: const Color(0x66000000),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Text('${comma(v)} / ${comma(max)}',
                textAlign: TextAlign.right, style: const TextStyle(color: AppColors.text, fontSize: 12)),
          ),
        ]);
    return Column(children: [
      bar('HP', t.hp, t.heroMaxHp, const Color(0xFFE25B5B), const Key('ashTurnHp')),
      if (t.mpMax > 0) ...[
        const SizedBox(height: 4),
        bar('MP', t.mp, t.mpMax, const Color(0xFFA86BFF), const Key('ashTurnMp')),
      ],
    ]);
  }

  Widget _commands(AshTurnInfo info) {
    Widget cell(AshCmd cmd, {required Widget icon, required String label, String? sub, bool glow = false, Key? key}) {
      final can = !_busy && t.can(cmd);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Opacity(
            opacity: can ? 1 : 0.4,
            child: GestureDetector(
              key: key ?? Key('ashCmd_${cmd.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: can ? () => _go(cmd) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: glow ? const [Color(0xFF3B2D5E), Color(0xFF2A2357)] : const [Color(0xFF262257), Color(0xFF201C4A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: glow ? AppColors.goldBright : const Color(0xFF6A5A2A), width: glow ? 2 : 1.4),
                  boxShadow: glow && can ? const [BoxShadow(color: Color(0x88E9C46A), blurRadius: 12)] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 30, height: 30, child: icon),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    Widget skillCell(AshCmd cmd) {
      final s = t.skillOf(cmd);
      if (s == null) {
        return cell(cmd,
            icon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
            label: '빈칸',
            sub: c.jobsOpen ? '스킬을 끼워요' : '직업 각성 뒤');
      }
      final js = JobRules.parseSkill(s.key);
      return cell(cmd,
          icon: js == null ? const Icon(Icons.auto_awesome) : SkillArt.jobIcon(js, size: 30),
          label: s.name,
          sub: t.skillsLocked ? '겁에 질려 잠김' : 'MP ${s.mp}');
    }

    final p = t.bestPotion;
    return Column(children: [
      Row(children: [
        cell(AshCmd.attack,
            icon: Image.asset('assets/images/fx_slash.webp', errorBuilder: (_, __, ___) => const Icon(Icons.flash_on)),
            label: '공격'),
        skillCell(AshCmd.skill1),
        skillCell(AshCmd.skill2),
      ]),
      Row(children: [
        cell(AshCmd.guard,
            icon: Image.asset('assets/images/fx_guard.webp', errorBuilder: (_, __, ___) => const Icon(Icons.shield)),
            label: '방어',
            sub: '받는 피해 절반'),
        cell(AshCmd.face,
            icon: const GameIcon('cheer', size: 30),
            label: '마주하기',
            sub: !t.faceOpen
                ? '아직 마음이 닫혀 있어'
                : t.allMemories
                    ? '${info.gauge} −2칸'
                    : '${info.gauge} −2칸 · 기억',
            glow: t.faceOpen),
        cell(AshCmd.potion,
            icon: const GameIcon('potion', size: 30),
            label: '물약',
            sub: p == null ? '물약이 없어요' : '남은 ${math.min(t.potionsLeftThisFight, p.count - (t.potionsUsed[p.key] ?? 0))}개'),
      ]),
    ]);
  }

  Widget _memoryPanel(AshTurnInfo info, int i) => GestureDetector(
        onTap: () {},
        child: Container(
          key: const Key('ashMemory'),
          color: const Color(0xEE0B0820),
          padding: const EdgeInsets.all(26),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('왕의 기억 · ${const ['하나', '둘', '셋'][i.clamp(0, 2)]}',
                style: const TextStyle(color: AppColors.gold, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 12),
            KText(info.memories[i.clamp(0, 2)],
                key: const Key('ashMemoryText'),
                textAlign: TextAlign.center,
                style: AppText.title(17, color: const Color(0xFFF3E9D0)).copyWith(height: 1.7)),
            const SizedBox(height: 12),
            Text('${info.gauge}이(가) 2칸 가라앉았어요 · 기억 ${i + 1} / 3',
                style: const TextStyle(color: Color(0xFFFFB27A), fontSize: 12)),
            const SizedBox(height: 18),
            FrameButton(
              key: const Key('ashMemoryNext'),
              label: '계속',
              onPressed: () => _memoryDone?.complete(),
            ),
          ]),
        ),
      );
}

class _Float {
  _Float(this.id, this.text, this.onFoe, this.color, this.big);
  final int id;
  final String text;
  final bool onFoe;
  final Color color;
  final bool big;
}

class _FloatNum extends StatelessWidget {
  const _FloatNum({super.key, required this.f, required this.left, required this.top});
  final _Float f;
  final double left;
  final double top;

  @override
  Widget build(BuildContext context) => Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 850),
            builder: (context, v, child) => Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, -40 * v), child: child),
            ),
            child: Text(f.text,
                style: TextStyle(
                  color: f.color,
                  fontSize: f.big ? 30 : 24,
                  fontWeight: FontWeight.w900,
                  shadows: const [Shadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 2)],
                )),
          ),
        ),
      );
}
