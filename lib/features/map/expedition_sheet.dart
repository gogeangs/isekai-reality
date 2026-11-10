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
import '../bulssi/bulssi_mood.dart';
import '../pets/pet_art.dart';
import '../battle/element_view.dart';

/// 정령 원정을 보낼 수 없는 이유
String expeditionReason(ExpeditionCheck c) => switch (c) {
      ExpeditionCheck.ok => '',
      ExpeditionCheck.needsLocation => '위치를 켜야 보낼 수 있어요',
      ExpeditionCheck.notEnoughMp => 'MP가 모자라요',
      ExpeditionCheck.busy => '이미 원정 중이에요',
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

class SpawnSheet extends StatefulWidget {
  const SpawnSheet({super.key, required this.controller, required this.spawn});

  final AppController controller;
  final FieldSpawn spawn;

  @override
  State<SpawnSheet> createState() => _SpawnSheetState();
}

class _SpawnSheetState extends State<SpawnSheet> {
  /// 보낼 펫 (정령이 떠난 뒤). null 이면 동행 펫, 동행 펫이 나가 있으면 쉬는 펫
  String? _petUid;

  AppController get controller => widget.controller;
  FieldSpawn get spawn => widget.spawn;

  String? get _chosen {
    final c = controller;
    if (!c.farewellDone) return null;
    if (_petUid != null && !c.isAway(_petUid)) return _petUid;
    final comp = c.companionPet;
    if (comp != null && !c.isAway(comp.uid)) return comp.uid;
    final idle = c.idlePets;
    return idle.isEmpty ? null : idle.first.uid;
  }

  @override
  Widget build(BuildContext context) {
    // 길을 찾으면 거리·MP·시간이 길 거리로 바뀐다 (11-11 #42)
    controller.prepareRoute(spawn);
    return ListenableBuilder(
        listenable: controller, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final c = controller;
    final info = spawn.info;
    final chosen = _chosen;
    final plan = c.planExpedition(spawn, petUid: chosen);
    final near = c.nearbySpawn?.id == spawn.id;
    final chosenPet = chosen == null ? null : c.pets.byUid(chosen);
    final spiritName = chosenPet?.name ?? c.companionName;

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
                    Row(children: [
                      ElementIcon(info.element, size: 18),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(spawn.name,
                            style: AppText.title(20,
                                color: modGradeColor(spawn.grade))),
                      ),
                    ]),
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
                      if (chosenPet != null)
                        PetArt.of(chosenPet, size: 36)
                      else
                        const CompanionArt(size: 36),
                      const SizedBox(width: 6),
                      Expanded(
                        child: KText('$spiritName 원정 보내기',
                            style: AppText.title(17)),
                      ),
                    ]),
                    if (c.farewellDone && c.pets.pets.length > 1) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final p in c.pets.pets)
                          ChoiceChip(
                            label: Text(c.isAway(p.uid)
                                ? '${p.name} (원정 중)'
                                : p.name),
                            selected: p.uid == chosen,
                            onSelected: c.isAway(p.uid)
                                ? null
                                : (_) => setState(() => _petUid = p.uid),
                            selectedColor: AppColors.gold,
                            backgroundColor: const Color(0xFF1E2250),
                            labelStyle: TextStyle(
                                color: p.uid == chosen
                                    ? AppColors.night
                                    : AppColors.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700),
                            showCheckmark: false,
                          ),
                      ]),
                      if (chosenPet != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: KText(
                              '특기: ${chosenPet.adult ? chosenPet.info.specialAdult : chosenPet.info.special}',
                              style: const TextStyle(
                                  color: AppColors.goldBright, fontSize: 12)),
                        ),
                    ],
                    const SizedBox(height: 8),
                    if (plan.check != ExpeditionCheck.needsLocation) ...[
                      _InfoRow(
                          label: '거리',
                          value: plan.distanceM >= 1000
                              ? '${(plan.distanceM / 1000).toStringAsFixed(1)}km'
                              : '${plan.distanceM.round()}m'
                                  '${!plan.routeReady ? ' (길 찾는 중…)' : plan.followsRoads ? ' (길 따라)' : ' (날아서)'}'),
                      _InfoRow(
                          label: 'MP',
                          value: '${plan.mpCost} 사용 (지금 ${c.mp} / '
                              '${c.mpMax})'),
                      _InfoRow(
                          label: '시간',
                          value: '가는 데 ${_minutes(plan.oneWay)}, '
                              '돌아오기까지 ${_minutes(plan.oneWay * 2)}'
                              '${c.compassReady ? ' (나침반으로 절반)' : ''}'),
                    ],
                    const SizedBox(height: 6),
                    KText(
                      '${c.farewellDone ? '펫' : '정령'}은 내 전투력으로 싸우고, 내 HP는 쓰지 않아요. '
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
                    // 11-11 #64: 가방에 마나 물약이 있으면 그 자리에서 마시기
                    if (plan.check == ExpeditionCheck.notEnoughMp)
                      ..._manaButtons(c, plan.mpCost - c.mp),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 11-11 #64: 보낼 수 없으면 흐리게 (눌리지 않음)
            Opacity(
              opacity: plan.check == ExpeditionCheck.ok ? 1 : 0.4,
              child: GoldButton(
              key: const Key('sendSpirit'),
              label: '${c.farewellDone ? spiritName : '정령'} 보내기',
              onPressed: plan.check == ExpeditionCheck.ok
                  ? () async {
                      final result =
                          await c.sendSpirit(spawn, petUid: chosen);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result == ExpeditionCheck.ok
                            ? '${josa(spiritName, '이/가')} 원정을 떠났어요. '
                                '${_minutes(plan.oneWay * 2)} 뒤에 돌아와요!'
                            : expeditionReason(result)),
                      ));
                    }
                  : null,
            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MP가 모자랄 때 마나 물약 버튼 (가장 알맞은 것 두 가지)
List<Widget> _manaButtons(AppController c, int need) {
  final opts = c.manaOptions(need);
  if (opts.isEmpty) return const [];
  final best = opts.first;
  return [
    const SizedBox(height: 8),
    for (final o in opts.take(2))
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: FrameButton(
          key: Key('mana_${o.item?.name ?? o.key}'),
          label: '${o.name} 마시기 · ${o.count}개 있음',
          height: 42,
          onPressed: () => c.drinkMana(o),
        ),
      ),
    if (best.bottles > 1)
      Text(
          best.bottles <= 3 && best.bottles <= best.count
              ? '${best.name} ${best.bottles}병 마시면 원정 가능'
              : '물약으로 채우기 어려워요',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
  ];
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
  const ExpeditionCard(
      {super.key, required this.controller, required this.ex, this.others = 0});

  final AppController controller;
  final Expedition ex;

  /// 함께 나가 있는 다른 원정 수
  final int others;

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
        if (ex.petUid != null && controller.pets.byUid(ex.petUid!) != null)
          PetArt.of(controller.pets.byUid(ex.petUid!)!, size: 48)
        else
          const CompanionArt(size: 48),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${ex.petName != null ? '${ex.petName} · ' : ''}'
                '${going ? '$name에게 가는 중' : '싸우고 돌아오는 중'}'
                '${others > 0 ? ' (외 $others마리)' : ''}',
                style: AppText.title(16),
              ),
              const SizedBox(height: 4),
              GlowBar(
                  ratio: total <= 0 ? 1 : (done / total).clamp(0.0, 1.0),
                  colors: BarColors.mana,
                  height: 7),
              const SizedBox(height: 2),
              KText(
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
