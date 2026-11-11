import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../../theme/top_notice.dart';

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

  AppController get c => widget.controller;

  static IconData icon(StatKind k) => switch (k) {
        StatKind.strength => Icons.fitness_center_rounded,
        StatKind.agility => Icons.directions_run_rounded,
        StatKind.intellect => Icons.auto_fix_high_rounded,
        StatKind.vitality => Icons.favorite_rounded,
        StatKind.luck => Icons.auto_awesome_rounded,
      };

  void _snack(String t) =>
      showTopNotice(context, t);

  Future<void> _reset() async {
    final cost = c.statResetCost;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('포인트를 되돌릴까요?',
            style: AppText.title(18, color: AppColors.text)),
        content: KText(
            '포인트로 올린 스탯만 되돌려서 다시 나눌 수 있어요. '
            '${cost == 0 ? '이번은 무료예요.' : '금화 $cost이 들어요.'}',
            style: const TextStyle(color: AppColors.text)),
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
            final cost = c.statResetCost;
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
                          fromPoints: alloc.of(k) + _draft.of(k),
                          adding: _draft.of(k),
                          canAdd: left > 0,
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
                      onPressed: _draft.total > 0
                          ? () async {
                              final ok = await c.allocateStats(_draft);
                              if (!mounted) return;
                              setState(() => _draft = Stats.zero);
                              if (ok) _snack('스탯을 올렸어요!');
                            }
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                OrnatePanel(
                  child: Row(children: [
                    Expanded(
                      child: KText(
                          '포인트로 올린 스탯만 되돌려 다시 나눌 수 있어요. '
                          '${cost == 0 ? '처음 1번은 무료예요.' : '이번에는 금화 $cost이 들어요.'}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: FrameButton(
                        label: '되돌리기',
                        height: 40,
                        onPressed: alloc.total > 0 ? _reset : null,
                      ),
                    ),
                  ]),
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
    required this.fromPoints,
    required this.adding,
    required this.canAdd,
    required this.onAdd,
    this.onRemove,
  });

  final StatKind kind;
  final IconData icon;
  final int total;
  final int fromPoints;
  final int adding;
  final bool canAdd;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0x66101333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.goldBright, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kind.label, style: AppText.title(16, color: AppColors.text)),
              KText(kind.role,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$total',
                style: AppText.title(20,
                    color: adding > 0 ? AppColors.goldBright : AppColors.text)),
            Text('포인트 +$fromPoints',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: '${kind.label} 빼기',
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppColors.gold,
        ),
        IconButton(
          tooltip: '${kind.label} 올리기',
          onPressed: canAdd ? onAdd : null,
          icon: const Icon(Icons.add_circle_rounded),
          color: AppColors.goldBright,
        ),
      ]),
    );
  }
}
