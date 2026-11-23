import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart' show HeroSprite, HeroPose, MonsterPicture;
import '../jobs/skill_icon.dart' show SkillArt;
import '../pets/pet_art.dart';

/// 묶음 83 #389: 하이랜드 수호자 턴제 화면.
/// 위: 수호자 이름 · HP 막대 · 상태 → 무대(수호자 · 다음 턴 말풍선 · 주인공 · 펫) →
/// 한 줄 소식 → 내 HP · MP → 명령 6칸(3 × 2). 말풍선이 「다음 턴에 할 일」을 미리 알려 주고,
/// 큰 기술은 붉은 테 + 이름. 처음 그 섬 수호자와 싸울 땐 맞는 명령에 초록 테(예고 세 번까지).
class SkyTurnView extends StatefulWidget {
  const SkyTurnView({
    super.key,
    required this.controller,
    required this.turn,
    required this.onFinished,
    this.fast = false,
    this.stepDelay = const Duration(milliseconds: 520),
  });

  final AppController controller;
  final SkyTurn turn;
  final VoidCallback onFinished;
  final bool fast;
  final Duration stepDelay;

  @override
  State<SkyTurnView> createState() => _SkyTurnViewState();
}

class _SkyTurnViewState extends State<SkyTurnView> {
  SkyTurn get t => widget.turn;
  AppController get c => widget.controller;

  bool _busy = false;
  String _log = '';

  bool _heroLunge = false;
  bool _heroHurt = false;
  bool _petLunge = false;
  bool _foeFlash = false;
  bool _shake = false;
  bool _redFlash = false;
  bool _guardFx = false;
  bool _breakFx = false;
  bool _hitFx = false;
  final List<_Float> _floats = [];
  int _floatId = 0;

  Duration get _d => widget.fast ? Duration(milliseconds: widget.stepDelay.inMilliseconds ~/ 2) : widget.stepDelay;

  @override
  void initState() {
    super.initState();
    _log = '${Monsters.info(t.info.guardian).name}이(가) 깨어났어요. 말풍선을 보고 명령을 골라요.';
  }

  Future<void> _wait([double k = 1]) => Future<void>.delayed(Duration(milliseconds: (_d.inMilliseconds * k).round()));

  void _float(String text, {required bool onFoe, Color color = Colors.white, bool big = false}) {
    final id = _floatId++;
    setState(() => _floats.add(_Float(id, text, onFoe, color, big)));
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
    });
  }

  Future<void> _go(SkyCmd cmd) async {
    if (_busy || !t.can(cmd)) return;
    setState(() => _busy = true);
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

  Future<void> _hitFoe(SkyEvent e, {bool pet = false}) async {
    setState(() => pet ? _petLunge = true : _heroLunge = true);
    await _wait(0.35);
    setState(() {
      _foeFlash = true;
      _hitFx = true;
      _shake = e.big;
      if (e.text.isNotEmpty) _log = e.text;
    });
    _float('${e.value}', onFoe: true, big: e.big, color: pet ? const Color(0xFF9FE0FF) : Colors.white);
    await _wait(0.3);
    setState(() {
      _foeFlash = false;
      _hitFx = false;
      _shake = false;
      _heroLunge = false;
      _petLunge = false;
    });
  }

  Future<void> _show(SkyEvent e) async {
    switch (e.kind) {
      case SkyEventKind.heroHit:
        await _hitFoe(e);
      case SkyEventKind.petSkill:
        await _hitFoe(e, pet: true);
      case SkyEventKind.petHit:
        await _hitFoe(e, pet: true);
      case SkyEventKind.armorBreak:
        setState(() {
          _breakFx = true;
          _log = e.text;
        });
        await _wait(0.6);
        setState(() => _breakFx = false);
      case SkyEventKind.heroGuard:
      case SkyEventKind.heroWall:
        setState(() {
          _guardFx = true;
          _log = e.text;
        });
      case SkyEventKind.heroPotion:
        _float('+${e.value}', onFoe: false, color: const Color(0xFF8DFFA8));
        setState(() => _log = e.text);
      case SkyEventKind.foeCharge:
        setState(() {
          _foeFlash = true;
          _log = e.text;
        });
        await _wait(0.4);
        setState(() => _foeFlash = false);
      case SkyEventKind.washed:
        setState(() {
          _guardFx = false;
          _log = e.text;
        });
      case SkyEventKind.foeSpecial:
        setState(() {
          _redFlash = e.value > 0 && e.big;
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
      case SkyEventKind.foeHit:
        await _wait(0.3);
        setState(() {
          _heroHurt = e.value > 0;
          if (e.value == 0) _log = e.text;
        });
        _float(e.value > 0 ? '-${e.value}' : '피함', onFoe: false, color: const Color(0xFFFF8A8A));
        await _wait(0.3);
        setState(() => _heroHurt = false);
      case SkyEventKind.foeHeal:
        _float('+${e.value}', onFoe: true, color: const Color(0xFFFFE680), big: true);
        setState(() => _log = e.text);
      case SkyEventKind.foeDown:
        setState(() => _log = '${Monsters.info(t.info.guardian).name}이(가) 우리를 인정했어요!');
      case SkyEventKind.heroDown:
        setState(() => _log = '쓰러졌어요…');
    }
    await _wait(0.5);
    if (mounted && !t.guarding && t.wall <= 0) setState(() => _guardFx = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _top(),
      const SizedBox(height: 6),
      Expanded(child: _stage()),
      const SizedBox(height: 4),
      Container(
        key: const Key('skyTurnLog'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(minHeight: 30),
        decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(8)),
        child: Text(_log, maxLines: 2, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      ),
      const SizedBox(height: 6),
      _meBars(),
      const SizedBox(height: 8),
      _commands(),
    ]);
  }

  Widget _chip(String text, Color color, Key key) => Container(
        key: key,
        margin: const EdgeInsets.only(right: 4, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xCC0E0C22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );

  Widget _top() {
    final ratio = t.foeMax <= 0 ? 0.0 : t.foeHp / t.foeMax;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(Monsters.info(t.info.guardian).name,
              style: AppText.title(17, color: AppColors.goldBright)),
        ),
        Text('${t.turn}턴', key: const Key('skyTurnNo'), style: AppText.title(14, color: AppColors.text)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          key: const Key('skyTurnFoeHp'),
          value: ratio.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: const Color(0x66000000),
          valueColor: const AlwaysStoppedAnimation(Color(0xFFF2C94C)),
        ),
      ),
      Wrap(children: [
        if (t.frost > 0) _chip('서리 갑옷', const Color(0xFFA8E6FF), const Key('skyFrostChip')),
        if (t.wall > 0) _chip('나: 막기 ${t.wall}턴', const Color(0xFF9FE0FF), const Key('skyWallChip')),
      ]),
    ]);
  }

  Widget _stage() {
    final i = t.info;
    final pet = c.companionPet;
    final big = t.bigNext;
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
            Image.asset(i.background,
                fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B2A40))),
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
            // 수호자
            Positioned(
              right: w * 0.04,
              top: h * 0.04,
              width: foeSize,
              height: foeSize,
              child: AnimatedOpacity(
                opacity: t.won ? 0.35 : 1,
                duration: const Duration(milliseconds: 400),
                child: ColorFiltered(
                  colorFilter: _foeFlash
                      ? const ColorFilter.mode(Color(0xCCFFFFFF), BlendMode.srcATop)
                      : t.frost > 0
                          ? const ColorFilter.mode(Color(0x5594D8FF), BlendMode.srcATop)
                          : const ColorFilter.mode(Color(0x00000000), BlendMode.srcATop),
                  child: Stack(fit: StackFit.expand, children: [
                    MonsterPicture(key: const Key('skyTurnFoe'), monster: i.guardian, size: foeSize),
                    if (_hitFx)
                      Image.asset('assets/images/fx_hit_${i.element.name}.webp',
                          key: const Key('skyHitFx'),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    if (_breakFx)
                      Image.asset('assets/images/fx_guardBreak.webp',
                          key: const Key('skyBreakFx'), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  ]),
                ),
              ),
            ),
            // 말풍선 (다음 턴에 할 일, 큰 기술은 붉게)
            if (!t.isOver)
              Positioned(
                left: 10,
                top: 10,
                width: math.min(200, w * 0.52),
                child: AnimatedContainer(
                  key: Key(big ? 'skySayWarn' : 'skySay'),
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                  decoration: BoxDecoration(
                    color: big ? const Color(0xDD5A1A0A) : const Color(0xCC1C1A44),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: big ? const Color(0xFFFF5A1F) : AppColors.gold, width: big ? 2 : 1.2),
                    boxShadow: big ? const [BoxShadow(color: Color(0x88FF5A4E), blurRadius: 12)] : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    KText(SkyTurnRules.intentLine(t.intent, t.isle),
                        key: const Key('skyIntent'),
                        style: AppText.title(13, color: big ? const Color(0xFFFFD7B8) : AppColors.text)
                            .copyWith(height: 1.4)),
                    const SizedBox(height: 2),
                    Text(SkyTurnRules.intentTip(t.intent),
                        style: TextStyle(
                            color: big ? const Color(0xFFFFB27A) : AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: big ? FontWeight.w800 : FontWeight.w500)),
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
                          key: const Key('skyGuardFx'), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                ]),
              ),
            ),
            if (pet != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                left: _petLunge ? w * 0.46 : w * 0.33,
                bottom: _petLunge ? h * 0.22 : 8,
                width: 60,
                height: 60,
                child: PetArt.of(pet, key: const Key('skyTurnPet'), size: 60),
              ),
            for (final f in _floats)
              _FloatNum(
                key: ValueKey('float${f.id}'),
                f: f,
                left: f.onFoe ? w * 0.6 : w * 0.12,
                top: f.onFoe ? h * 0.25 : h * 0.5,
              ),
            if (_redFlash)
              const Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Color(0x55FF3A1F)))),
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
      bar('HP', t.hp, t.heroMaxHp, const Color(0xFFE25B5B), const Key('skyTurnHp')),
      if (t.mpMax > 0) ...[
        const SizedBox(height: 4),
        bar('MP', t.mp, t.mpMax, const Color(0xFFA86BFF), const Key('skyTurnMp')),
      ],
    ]);
  }

  Widget _commands() {
    final hinted = _busy ? const <SkyCmd>{} : t.hinted;
    Widget cell(SkyCmd cmd, {required Widget icon, required String label, String? sub}) {
      final can = !_busy && t.can(cmd);
      final hint = hinted.contains(cmd);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Opacity(
            opacity: can ? 1 : 0.4,
            child: GestureDetector(
              key: Key('skyCmd_${cmd.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: can ? () => _go(cmd) : null,
              child: AnimatedContainer(
                key: hint ? Key('skyHint_${cmd.name}') : null,
                duration: const Duration(milliseconds: 300),
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF262257), Color(0xFF201C4A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hint ? const Color(0xFF6BD97A) : const Color(0xFF6A5A2A), width: hint ? 2.2 : 1.4),
                  boxShadow: hint ? const [BoxShadow(color: Color(0x886BD97A), blurRadius: 12)] : null,
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

    Widget skillCell(SkyCmd cmd) {
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
          sub: 'MP ${s.mp}');
    }

    final p = t.bestPotion;
    final pet = c.companionPet;
    return Column(children: [
      Row(children: [
        cell(SkyCmd.strike,
            icon: Image.asset('assets/images/fx_slash.webp', errorBuilder: (_, __, ___) => const Icon(Icons.flash_on)),
            label: '강타',
            sub: t.frost > 0 ? '서리 갑옷을 깨요' : '기본 공격'),
        skillCell(SkyCmd.skill1),
        skillCell(SkyCmd.skill2),
      ]),
      Row(children: [
        cell(SkyCmd.guard,
            icon: Image.asset('assets/images/fx_guard.webp', errorBuilder: (_, __, ___) => const Icon(Icons.shield)),
            label: '방어',
            sub: '이번 턴 절반'),
        cell(SkyCmd.petSkill,
            icon: pet == null
                ? const Icon(Icons.pets_rounded, color: AppColors.textMuted)
                : PetArt.of(pet, size: 30),
            label: pet == null ? '펫 스킬' : pet.info.skillName,
            sub: pet == null
                ? '함께하는 펫이 없어요'
                : t.petWait > 0
                    ? '${t.petWait}턴 뒤'
                    : '준비됨'),
        cell(SkyCmd.potion,
            icon: const GameIcon('potion', size: 30),
            label: '물약',
            sub: p == null ? '물약이 없어요' : '남은 ${math.min(t.potionsLeftThisFight, p.count - (t.potionsUsed[p.key] ?? 0))}개'),
      ]),
    ]);
  }
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
