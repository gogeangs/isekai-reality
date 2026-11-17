import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../act3/ally_screens.dart' show AllyTab;
import '../awakening/awakening_screen.dart' show IllustratedScene;
import '../tutorial/feature_tour.dart' show TourScreenMark;
import 'npc_header.dart';

/// 마을 새 건물 「주점」 (묶음 51 #242): 리안 · 파티 창구(서버 전엔 준비 중) · 소문판 · 한 끼 식사
class TavernScreen extends StatefulWidget {
  const TavernScreen({super.key, required this.controller, this.allyTab = false});

  final AppController controller;

  /// 처음부터 「동료」 탭 (묶음 52: 3막 화면에서 동료 얼굴을 눌러 올 때)
  final bool allyTab;

  @override
  State<TavernScreen> createState() => _TavernScreenState();
}

class _TavernScreenState extends State<TavernScreen> {
  AppController get c => widget.controller;

  /// 방금 들은 소문 (오늘 이미 들었으면 처음부터 보임)
  late String? _rumor = c.rumorHeardToday ? c.todayRumor : null;

  /// 묶음 52 #243: 3막이 열리면 「주점 | 동료」 두 탭
  late bool _allies = widget.allyTab && c.act3Open;

  Future<void> _hear() async {
    final r = await c.hearRumor();
    if (mounted) setState(() => _rumor = r);
  }

  Future<void> _eat(Meal m) async {
    final ok = await c.eatMeal(m);
    if (!mounted) return;
    if (!ok) {
      showTopNotice(context, '금화가 모자라요', icon: Icons.info_outline_rounded);
      return;
    }
    showTopNotice(context, '${josa(TavernRules.meal(m).name, '을/를')} 먹었어요 · ${TavernRules.meal(m).text}',
        icon: Icons.restaurant_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'tavern',
      child: Scaffold(
        key: const Key('tavernScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                    title: '주점', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 6),
                NpcHeader(
                    controller: c, npc: Npc.lian, guide: VillageRules.tavernGuide),
                if (c.act3Open) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (i, t) in const ['주점', '동료'].indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          key: Key('tavernTab_$i'),
                          label: SizedBox(
                              width: double.infinity,
                              child: Text(t, textAlign: TextAlign.center)),
                          selected: _allies == (i == 1),
                          onSelected: (_) => setState(() => _allies = i == 1),
                        ),
                      ),
                    ],
                  ]),
                ],
                const SizedBox(height: 10),
                if (_allies)
                  AllyTab(controller: c)
                else ...[
                  _party(),
                  const SizedBox(height: 10),
                  _rumors(),
                  const SizedBox(height: 10),
                  _meals(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _party() => OrnatePanel(
        key: const Key('tavernParty'),
        child: Row(children: [
          const Icon(Icons.groups_rounded, color: AppColors.textMuted, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(TavernRules.partyName, style: AppText.title(17)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                    ),
                    child: const Text(TavernRules.partySoon,
                        key: Key('tavernPartySoon'),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 4),
                const KText(TavernRules.partyLine,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ]),
      );

  Widget _rumors() {
    final r = _rumor;
    return OrnatePanel(
      key: const Key('tavernRumor'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.campaign_rounded, color: AppColors.goldBright, size: 22),
            const SizedBox(width: 6),
            Text('소문판', style: AppText.title(17)),
          ]),
          const SizedBox(height: 8),
          if (r == null)
            Center(
              child: GoldButton(
                key: const Key('tavernHear'),
                label: '리안에게 소문 듣기',
                height: 44,
                onPressed: _hear,
              ),
            )
          else ...[
            Container(
              key: const Key('tavernRumorText'),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE9DDC4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x998A6F45)),
              ),
              child: KText('「$r」',
                  style: const TextStyle(
                      color: Color(0xFF3A2C1A),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            const KText(TavernRules.rumorAgain,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _meals() {
    final eaten = c.todayMeal;
    return OrnatePanel(
      key: const Key('tavernMeals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.restaurant_rounded, color: AppColors.goldBright, size: 22),
            const SizedBox(width: 6),
            Expanded(child: Text('한 끼 식사', style: AppText.title(17))),
            Text('금화 ${c.player.gold}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          KText(
              eaten == null
                  ? '하루 한 번, 셋 중 하나를 골라요. 오늘 자정까지 걸을 때만 효과가 있어요.'
                  : '오늘은 ${josa(TavernRules.meal(eaten).name, '을/를')} 먹었어요. 내일 또 와요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 8),
          for (final m in TavernRules.meals) _mealRow(m, eaten),
        ],
      ),
    );
  }

  Widget _mealRow(MealInfo m, Meal? eaten) {
    final price = c.mealPrice(m.id);
    final mine = eaten == m.id;
    final can = eaten == null && c.player.gold >= price;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Opacity(
        opacity: eaten == null || mine ? 1 : 0.45,
        child: Row(children: [
          Image.asset(m.asset,
              key: Key('food_${m.id.name}'),
              width: 52,
              height: 52,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.restaurant_rounded, size: 40, color: AppColors.gold)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                KText(m.text,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          mine
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.check_circle_rounded, color: AppColors.goldBright),
                )
              : TextButton(
                  key: Key('eat_${m.id.name}'),
                  style: gameButtonStyle(gold: can),
                  onPressed: can ? () => _eat(m.id) : null,
                  child: Text('금화 $price'),
                ),
        ]),
      ),
    );
  }
}

/// 거래소 (묶음 51 #229, 서버 전): 바르칸 · 장은 아직 안 열림 (거래는 서버 때)
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'market',
      child: Scaffold(
        key: const Key('marketScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListView(
            padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
            children: [
              OrnateTopBar(
                  title: '거래소', onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 6),
              NpcHeader(controller: c, npc: Npc.barkan, guide: VillageRules.marketGuide),
              const SizedBox(height: 10),
              OrnatePanel(
                key: const Key('marketClosed'),
                child: Column(children: [
                  Row(children: [
                    for (final t in const ['사기', '값 정해 올리기', '경매'])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.abyss,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                          ),
                          child: Text(t,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  const Icon(Icons.menu_book_rounded, color: AppColors.goldBright, size: 34),
                  const SizedBox(height: 6),
                  const KText('장이 아직 열리지 않았어요.\n각성자들이 더 모이면 바르칸이 장을 열어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.5)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 결말 뒤 처음 마을에 올 때 만남 장면 (묶음 51 #242). 낯선 불빛들 → 리안이 손을 내밂.
/// 도중에 앱을 끄면 다음에 처음부터, 마지막 줄을 넘기면 본 것으로.
class MeetScreen extends StatefulWidget {
  const MeetScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  AppController get c => widget.controller;
  int _line = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _next() async {
    if (_line < TavernRules.meet.length - 1) {
      setState(() => _line++);
      return;
    }
    if (_done) return;
    _done = true;
    await c.markMeetSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final (lian, line) = TavernRules.meet[_line];
    final lianArt = _line >= TavernRules.lianFrom;
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('meetScreen'),
        backgroundColor: AppColors.deepNight,
        body: IllustratedScene(
          key: ValueKey('meet$_line'),
          image: lianArt ? TavernRules.sceneLian : TavernRules.sceneLights,
          speaker: lian
              ? VillageRules.npc(Npc.lian).name
              : c.firstPet?.name ?? c.voicePet?.name ?? '펫',
          // 리안이 손을 내민 그림은 손이 아래쪽이라 대사창을 위에
          dialogTop: lianArt,
          tailUp: false,
          tailX: lian ? 0.55 : 0.3,
          line: line,
          lineKey: 'meet-$_line',
          onNext: _next,
        ),
      ),
    );
  }
}
