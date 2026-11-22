import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart' show Pet;
import '../../core/models/vitals.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../pets/pet_art.dart';
import 'expedition_sheet.dart' show expeditionReason;
import 'pet_picker.dart';

String _dist(double m) => m < 1000 ? '${m.round()}m' : '${(m / 1000).toStringAsFixed(1)}km';

/// 묶음 81 #375: 지도에서 잿빛 틈 · 하이랜드 섬을 눌렀을 때 — 「걸어서 가기(○m)」 + 「원정 보내기」.
/// [kind] 'rift' · 'sky'. [title] 창 제목, [about] 한 줄 설명, [onEnter] 걸어서 닿았거나 펫이 기다릴 때 들어가기.
Future<void> showTripSheet(
  BuildContext context,
  AppController c, {
  required String kind,
  required String title,
  required String about,
  double? distanceM,
  required Future<void> Function() onEnter,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (s) => TripSheet(
          controller: c, kind: kind, title: title, about: about, distanceM: distanceM, onEnter: onEnter),
    );

class TripSheet extends StatefulWidget {
  const TripSheet({
    super.key,
    required this.controller,
    required this.kind,
    required this.title,
    required this.about,
    this.distanceM,
    required this.onEnter,
  });

  final AppController controller;
  final String kind;
  final String title;
  final String about;
  final double? distanceM;
  final Future<void> Function() onEnter;

  @override
  State<TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<TripSheet> {
  String? _pick;

  AppController get c => widget.controller;

  String? get _chosen {
    if (_pick != null && c.petCanSend(_pick!)) return _pick;
    final comp = c.companionPet;
    if (comp != null && c.petCanSend(comp.uid)) return comp.uid;
    for (final p in c.pets.pets) {
      if (c.petCanSend(p.uid)) return p.uid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              key: Key('tripSheet_${widget.kind}'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: AppText.title(19)),
                const SizedBox(height: 6),
                KText(widget.about, style: const TextStyle(color: AppColors.text, height: 1.45)),
                if (widget.distanceM != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.directions_walk_rounded, color: AppColors.goldBright, size: 18),
                    const SizedBox(width: 4),
                    Text('걸어서 가기 (${_dist(widget.distanceM!)})',
                        key: const Key('tripWalk'),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ]),
                ],
                const SizedBox(height: 12),
                ..._body(context),
              ],
            ),
          ),
        ),
      );

  List<Widget> _body(BuildContext context) {
    final now = c.now;
    final trip = c.tripTo(widget.kind);
    if (trip != null) return _tripStatus(context, trip, now);
    if (!c.canOfferTrip(widget.kind)) {
      return [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('알겠어요')),
        ),
      ];
    }
    final chosen = _chosen;
    final pets = c.pets.pets;
    final plan = c.planTrip(widget.kind, petUid: chosen);
    final pet = chosen == null ? null : c.pets.byUid(chosen);
    final noneFree = chosen == null;
    final back = c.firstPetBack;
    final String label;
    if (noneFree) {
      label = '모두 원정 중이에요${back == null ? '' : ' · ${petPickMinutes(back)} 뒤 돌아와요'}';
    } else if (plan.tooLate) {
      label = '섬이 지기 전에 닿지 못해요';
    } else {
      label = '${pet!.name} 원정 보내기';
    }
    return [
      OrnatePanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const GameIcon('expedition', size: 36),
              const SizedBox(width: 6),
              if (pet != null) ...[PetArt.of(pet, size: 32), const SizedBox(width: 6)],
              Expanded(
                child: KText(pet == null ? '원정 보내기' : '${pet.name} 원정 보내기',
                    key: const Key('tripHead'), style: AppText.title(16)),
              ),
            ]),
            if (pets.length > 1) ...[
              const SizedBox(height: 6),
              ExpeditionPetPicker(
                controller: c,
                pets: pets,
                chosen: chosen,
                onPick: (uid) => setState(() => _pick = uid),
              ),
            ],
            if (pet != null && plan.check != ExpeditionCheck.needsLocation) ...[
              const SizedBox(height: 6),
              _row('거리', _dist(plan.distanceM)),
              _row('기력', '${plan.mpCost} 사용 (지금 ${c.mp} / ${c.mpMax})'),
              _row('시간', '가는 데 ${petPickMinutes(plan.oneWay)}'),
            ],
            const SizedBox(height: 6),
            KText(
              widget.kind == 'rift'
                  ? '닿으면 알려 줄게요. 그때부터 30분 기다리는 동안 들어가 싸울 수 있어요(내 HP를 써요).'
                  : '닿으면 알려 줄게요. 섬이 질 때까지(30분까지) 기다리는 동안 오를 수 있어요(내 HP를 써요).',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
            ),
            if (pet != null && plan.check != ExpeditionCheck.ok && !plan.tooLate) ...[
              const SizedBox(height: 4),
              Text(expeditionReason(plan.check),
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ],
            // 묶음 81 #373: 쉬는 중이면 여관 회복이 멈춤
            if (c.resting && !noneFree)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('보내면 여관 회복이 멈춰요',
                    key: Key('tripInnPause'), style: TextStyle(color: AppColors.goldBright, fontSize: 12)),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Opacity(
        opacity: plan.ok ? 1 : 0.4,
        child: GoldButton(
          key: const Key('tripSend'),
          label: label,
          onPressed: plan.ok && chosen != null
              ? () async {
                  final r = await c.sendTrip(widget.kind, chosen);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  showTopNotice(
                      context,
                      r == ExpeditionCheck.ok
                          ? '${josa(pet!.name, '이/가')} 떠났어요. ${petPickMinutes(plan.oneWay)} 뒤에 닿아요!'
                          : expeditionReason(r));
                }
              : null,
        ),
      ),
    ];
  }

  List<Widget> _tripStatus(BuildContext context, SpotTrip t, DateTime now) {
    final where = widget.kind == 'rift' ? '잿빛 틈' : '섬 아래';
    final String line;
    if (t.going(now)) {
      line = '${josa(t.petName, '이/가')} $where로 가는 중 · ${petPickMinutes(t.arriveAt.difference(now))} 뒤 닿아요';
    } else if (t.waiting(now)) {
      line = '${josa(t.petName, '이/가')} $where에서 기다려요 · ${petPickMinutes(t.waitUntil.difference(now))} 남음';
    } else {
      line = '${josa(t.petName, '이/가')} 돌아오는 중 · ${petPickMinutes(t.returnAt.difference(now))}';
    }
    return [
      Row(children: [
        if (c.pets.byUid(t.petUid) case final Pet p) ...[PetArt.of(p, size: 40), const SizedBox(width: 8)],
        Expanded(
            child: KText(line,
                key: const Key('tripStatus'),
                style: const TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      if (t.waiting(now))
        GoldButton(
          key: const Key('tripEnter'),
          label: widget.kind == 'rift' ? '싸우러 가기' : '섬에 오르러 가기',
          onPressed: () async {
            Navigator.of(context).pop();
            await widget.onEnter();
          },
        )
      else
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('알겠어요')),
        ),
    ];
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 44, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 14))),
          Expanded(child: Text(v, style: const TextStyle(color: AppColors.text, fontSize: 14))),
        ]),
      );
}
