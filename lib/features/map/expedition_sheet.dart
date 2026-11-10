import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/vitals.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/dungeon_screen.dart' show confirmStopResting;
import '../battle/field_battle_screen.dart';
import '../battle/modifier_view.dart';
import '../bulssi/spirit_art.dart';

/// 정령 원정을 보낼 수 없는 이유
String expeditionReason(ExpeditionCheck c) => switch (c) {
      ExpeditionCheck.ok => '',
      ExpeditionCheck.needsLocation => '위치를 켜야 보낼 수 있어요',
      ExpeditionCheck.notEnoughMp => 'MP가 모자라요',
      ExpeditionCheck.busy => '정령이 이미 원정 중이에요',
    };

String _minutes(Duration d) {
  final m = d.inMinutes;
  if (m >= 60) return '${m ~/ 60}시간 ${m % 60}분';
  return '${m < 1 ? 1 : m}분';
}

/// 지도에서 필드 몬스터를 눌렀을 때: 직접 정화(가까이 있을 때) 또는 정령 보내기
Future<void> showSpawnSheet(
  BuildContext context,
  AppController c,
  FieldSpawn spawn,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SpawnSheet(controller: c, spawn: spawn),
  );
}

class SpawnSheet extends StatelessWidget {
  const SpawnSheet({super.key, required this.controller, required this.spawn});

  final AppController controller;
  final FieldSpawn spawn;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = spawn.info;
    final plan = c.planExpedition(spawn);
    final near = c.nearbySpawn?.id == spawn.id;
    final spiritName = c.profile.spiritName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              MonsterPicture(monster: spawn.monster, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spawn.name,
                        style: AppText.title(20,
                            color: modGradeColor(spawn.grade))),
                    const SizedBox(height: 4),
                    Text(info.habitat,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ]),
            if (spawn.modifiers.isNotEmpty) ...[
              const SizedBox(height: 10),
              ModifierPanel(mods: spawn.modifiers),
            ],
            const SizedBox(height: 14),
            if (near) ...[
              GoldButton(
                label: '직접 사냥하기',
                onPressed: c.hp <= 0
                    ? null
                    : () async {
                        if (c.resting) {
                          final ok = await confirmStopResting(context);
                          if (!ok || !context.mounted) return;
                        }
                        Navigator.of(context).pop();
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FieldBattleScreen(controller: c, spawn: spawn),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 10),
            ],
            OrnatePanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const GameIcon('expedition', size: 40),
                      const SizedBox(width: 6),
                      SpiritArt(kind: c.profile.spiritKind, size: 36),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('$spiritName 원정 보내기',
                            style: AppText.title(17)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (plan.check != ExpeditionCheck.needsLocation) ...[
                      _InfoRow(
                          label: '거리',
                          value: plan.distanceM >= 1000
                              ? '${(plan.distanceM / 1000).toStringAsFixed(1)}km'
                              : '${plan.distanceM.round()}m'),
                      _InfoRow(
                          label: 'MP',
                          value: '${plan.mpCost} 사용 (지금 ${c.mp} / '
                              '${RuleConstants.mpMax})'),
                      _InfoRow(
                          label: '시간',
                          value: '가는 데 ${_minutes(plan.oneWay)}, '
                              '돌아오기까지 ${_minutes(plan.oneWay * 2)}'
                              '${c.compassReady ? ' (나침반으로 절반)' : ''}'),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      '정령은 내 전투력으로 싸우고, 내 HP는 쓰지 않아요. '
                      '지면 MP만 쓰고 무사히 돌아와요.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12, height: 1.35),
                    ),
                    if (plan.check != ExpeditionCheck.ok) ...[
                      const SizedBox(height: 6),
                      Text(expeditionReason(plan.check),
                          style: const TextStyle(
                              color: AppColors.goldBright,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            GoldButton(
              label: '정령 보내기',
              onPressed: plan.check == ExpeditionCheck.ok
                  ? () async {
                      final result = await c.sendSpirit(spawn);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result == ExpeditionCheck.ok
                            ? '$spiritName이(가) 원정을 떠났어요. '
                                '${_minutes(plan.oneWay * 2)} 뒤에 돌아와요!'
                            : expeditionReason(result)),
                      ));
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 44,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ]),
      );
}

/// 원정 중인 정령 안내 (지도 아래)
class ExpeditionCard extends StatelessWidget {
  const ExpeditionCard({super.key, required this.controller, required this.ex});

  final AppController controller;
  final Expedition ex;

  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final going = ex.goingAt(now);
    final total = ex.returnAt.difference(ex.startedAt).inSeconds;
    final done = now.difference(ex.startedAt).inSeconds;
    final left = ex.returnAt.difference(now);
    final id = Monsters.byName(ex.monster);
    final name = id == null ? '몬스터' : Monsters.info(id).name;
    return OrnatePanel(
      child: Row(children: [
        SpiritArt(kind: controller.profile.spiritKind, size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                going ? '$name에게 가는 중' : '싸우고 돌아오는 중',
                style: AppText.title(16),
              ),
              const SizedBox(height: 4),
              GlowBar(
                  ratio: total <= 0 ? 1 : (done / total).clamp(0.0, 1.0),
                  colors: BarColors.mana,
                  height: 7),
              const SizedBox(height: 2),
              Text(
                '${_minutes(left.isNegative ? Duration.zero : left)} 뒤 도착 · '
                'MP ${ex.mpCost} 사용 · ${comma(ex.distanceM.round())}m',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
