import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../../theme/top_notice.dart';
import 'stat_icon.dart';

/// 스탯 포인트 분배 (11-11 #50).
/// 합계와 '포인트로 올린 값'만 보여 준다. 생활 활동으로 오른 값은 따로 보여 주지 않는다.
class StatScreen extends StatefulWidget {
  const StatScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> {
  /// 아직 확정하지 않은 분배
  Stats _draft = Stats.zero;

  /// 확정할 때 바뀐 스탯 숫자를 금빛으로 한 번 반짝인다 (11-11 #85)
  Set<StatKind> _flash = {};
  int _flashTick = 0;

  AppController get c => widget.controller;

  static IconData icon(StatKind k) => StatIcon.fallback(k);

  void _snack(String t) =>
      showTopNotice(context, t);

  Future<void> _reset() async {
    final cost = c.statResetCost;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text(
            cost == 0 ? '무료로 되돌릴까요?' : '금화 $cost으로 되돌릴까요?',
            style: AppText.title(18, color: AppColors.text)),
        content: const KText('포인트로 올린 스탯만 되돌려 다시 나눌 수 있어요.',
            style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('그만두기')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('되돌리기')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await c.resetStats();
    if (!mounted) return;
    setState(() => _draft = Stats.zero);
    _snack(done ? '포인트를 되돌렸어요. 다시 나눠 주세요!' : '금화가 모자라요.');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final left = c.unspentPoints - _draft.total;
            final shown = c.shownStats;
            final alloc = c.allocatedStats;
            // 묶음 15 #110·#111: −·+ 와 「고르게 나누기」「확정」은 나눌 때만
            final dividing = c.unspentPoints > 0 || _draft.total > 0;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '스탯',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                BulssiLine(
                    line: c.unspentPoints > 0
                        ? '레벨이 오를 때마다 포인트 ${StatRules.pointsPerLevel}개가 생겨. 어디에 쓸까?'
                        : '포인트를 다 나눴어! 레벨이 오르면 또 생겨.'),
                const SizedBox(height: 10),
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Text('남은 포인트', style: AppText.title(17)),
                        const Spacer(),
                        Text('$left',
                            style: AppText.title(24,
                                color: left > 0
                                    ? AppColors.goldBright
                                    : AppColors.textMuted)),
                      ]),
                      const SizedBox(height: 4),
                      for (final k in StatKind.values)
                        _StatRow(
                          kind: k,
                          icon: icon(k),
                          total: shown.of(k) + _draft.of(k),
                          adding: _draft.of(k),
                          canAdd: left > 0,
                          dividing: dividing,
                          flash: _flash.contains(k),
                          flashTick: _flashTick,
                          onAdd: () => setState(
                              () => _draft = _draft.withValue(k, _draft.of(k) + 1)),
                          onRemove: _draft.of(k) > 0
                              ? () => setState(() =>
                                  _draft = _draft.withValue(k, _draft.of(k) - 1))
                              : null,
                        ),
                    ],
                  ),
                ),
                if (dividing) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FrameButton(
                      label: '고르게 나누기',
                      height: 44,
                      onPressed: left > 0
                          ? () => setState(
                              () => _draft = _draft + StatRules.evenShare(left))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GoldButton(
                      label: '확정',
                      height: 44,
                      // 정령 말풍선이 알려 주므로 알림 띠는 띄우지 않는다
                      onPressed: _draft.total > 0 && c.unspentPoints > 0
                          ? () async {
                              final changed = {
                                for (final k in StatKind.values)
                                  if (_draft.of(k) > 0) k,
                              };
                              final ok = await c.allocateStats(_draft);
                              if (!mounted) return;
                              setState(() {
                                _draft = Stats.zero;
                                if (ok) {
                                  _flash = changed;
                                  _flashTick++;
                                }
                              });
                            }
                          : null,
                    ),
                  ),
                ]),
                ],
                const SizedBox(height: 16),
                // 되돌리기: 버튼만. 비용은 누르면 뜨는 확인 창에서
                Center(
                  child: SizedBox(
                    width: 160,
                    child: FrameButton(
                      key: const Key('statReset'),
                      label: '되돌리기',
                      height: 40,
                      onPressed: alloc.total > 0 ? _reset : null,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.kind,
    required this.icon,
    required this.total,
    required this.adding,
    required this.canAdd,
    required this.onAdd,
    required this.dividing,
    this.onRemove,
    this.flash = false,
    this.flashTick = 0,
  });

  final bool flash;
  final int flashTick;

  final StatKind kind;
  final IconData icon;
  final int total;
  final int adding;
  final bool canAdd;
  final bool dividing;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  /// 메달 크기 (묶음 15 #109: 줄 높이에 꽉 차게, 예전의 약 2배)
  static const double medal = 52;

  @override
  Widget build(BuildContext context) {
    final number = flash
        ? TweenAnimationBuilder<double>(
            key: ValueKey('flash_$flashTick'),
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 1100),
            builder: (_, v, __) => Transform.scale(
              scale: 1 + 0.25 * v,
              child: Text('$total',
                  style: AppText.title(22,
                          color: Color.lerp(
                              AppColors.text, AppColors.goldBright, v)!)
                      .copyWith(shadows: [
                    Shadow(
                        color: AppColors.gold.withValues(alpha: v),
                        blurRadius: 14 * v),
                  ])),
            ),
          )
        : Text('$total',
            key: Key('statValue_${kind.name}'),
            style: AppText.title(22,
                color: adding > 0 ? AppColors.goldBright : AppColors.text));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0x66101333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // 스탯이 하는 일은 메달을 누르면 작은 말풍선으로
        Tooltip(
          key: Key('statMedal_${kind.name}'),
          message: kind.role,
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 3),
          child: StatIcon(kind, size: medal, color: AppColors.goldBright),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(kind.label, style: AppText.title(18, color: AppColors.text)),
        ),
        if (dividing) ...[
          IconButton(
            tooltip: '${kind.label} 빼기',
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.gold,
          ),
          SizedBox(width: 44, child: Center(child: number)),
          IconButton(
            tooltip: '${kind.label} 올리기',
            onPressed: canAdd ? onAdd : null,
            icon: const Icon(Icons.add_circle_rounded),
            color: AppColors.goldBright,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: number,
          ),
      ]),
    );
  }
}
