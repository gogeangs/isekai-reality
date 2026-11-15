import 'dart:async';

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
import '../tutorial/feature_tour.dart' show TourScreenMark;
import 'npc_header.dart';

/// 펫 쉼터 (묶음 35): Lv.11 첫 펫과 함께 열린다.
/// 알 부화장(품은 알을 둥지에 놓인 모습으로, 규칙은 가방과 같다) +
/// 원정에서 지친 펫 쉬게 하기(쉼터에서 쉬면 그때부터 15분 뒤 풀림).
class ShelterScreen extends StatefulWidget {
  const ShelterScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ShelterScreen> createState() => _ShelterScreenState();
}

class _ShelterScreenState extends State<ShelterScreen> {
  Timer? _tick;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    // 남은 시간이 흐르게
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _left(Duration d) {
    final m = (d.inSeconds + 59) ~/ 60;
    if (m >= 60) return '${m ~/ 60}시간 ${m % 60}분';
    return '$m분';
  }

  Future<void> _openEgg(PetEgg e) async {
    if (c.eggReady(e)) {
      await showHatchSheet(context, c, e);
    } else {
      await showBagEntry(context, c, EggEntry(e));
    }
  }

  Future<void> _rest(Pet p) async {
    final ok = await c.restInShelter(p.uid);
    if (ok && mounted) {
      showTopNotice(context, '${p.name}, 쉼터에서 푹 쉬어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'shelter',
      child: Scaffold(
        key: const Key('shelterScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final eggs = c.pets.eggs;
              final tired = c.tiredPets;
              return ListView(
                padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
                children: [
                  OrnateTopBar(
                    title: '펫 쉼터',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 6),
                  // 묶음 38 #213: 정령 띠 대신 마을 사람이 안내
                  NpcHeader(
                      controller: c,
                      npc: Npc.lumi,
                      guide: VillageRules.shelterGuide),
                  const SizedBox(height: 10),
                  // ───── 알 부화장
                  OrnatePanel(
                    key: const Key('shelterNests'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('알 부화장', style: AppText.title(17)),
                        const SizedBox(height: 8),
                        if (eggs.isEmpty)
                          const KText('지금은 알이 없어요. 알을 얻으면 둥지에 놓아 둘게요.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13))
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final e in eggs) _nest(e),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ───── 지친 펫
                  OrnatePanel(
                    key: const Key('shelterTired'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('쉬는 펫', style: AppText.title(17)),
                        const SizedBox(height: 4),
                        const KText(
                            '원정에서 진 펫은 잠시 지쳐서 원정을 못 가요. 동행과 던전은 그대로 함께해요.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 8),
                        if (tired.isEmpty)
                          const KText('지친 펫이 없어요.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        for (final p in tired) _tiredRow(p),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _nest(PetEgg e) {
    final ready = c.eggReady(e);
    final String label;
    if (e.incubatedAt == null) {
      label = '품기 전';
    } else if (ready) {
      label = '깨어나려 해요!';
    } else {
      label = '${_left(e.incubatedAt!.add(PetRules.hatchTime).difference(c.now))} 남음';
    }
    return GestureDetector(
      key: Key('nest_${e.id}'),
      onTap: () => _openEgg(e),
      child: SizedBox(
        width: 96,
        child: Column(children: [
          SizedBox(
            width: 96,
            height: 86,
            child: Stack(alignment: Alignment.bottomCenter, children: [
              // 짚 둥지
              Positioned(
                bottom: 4,
                child: Container(
                  width: 84,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: const RadialGradient(colors: [
                      Color(0xFF8A6A3A),
                      Color(0xFF5A4022),
                    ]),
                    border: Border.all(color: const Color(0xFFC9A05A), width: 2),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                child: EggArt(
                    size: 60, glowing: ready || e.incubatedAt != null),
              ),
            ]),
          ),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ready ? AppColors.goldBright : AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _tiredRow(Pet p) {
    final left = c.petTiredLeft(p.uid) ?? Duration.zero;
    final resting = c.petInShelter(p.uid);
    return Padding(
      key: Key('tired_${p.uid}'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Opacity(opacity: 0.75, child: PetArt.of(p, size: 46)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: AppText.title(15, color: AppColors.text)),
              Text(
                  resting
                      ? '쉼터에서 쉬는 중 · ${_left(left)} 남음'
                      : '지쳐서 쉬는 중 · ${_left(left)} 남음',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        if (!resting)
          TextButton(
            key: Key('shelterRest_${p.uid}'),
            style: gameButtonStyle(gold: true),
            onPressed: () => _rest(p),
            child: const Text('쉼터에서 쉬기'),
          ),
      ]),
    );
  }
}
