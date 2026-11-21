part of '../erbard_screens.dart';

class _Dots extends StatelessWidget {
  const _Dots({required this.broken, this.defend = false});
  final List<int> broken;

  /// 우리 영지: 남은 자리를 금빛으로
  final bool defend;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xC00B0D26), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var k = 0; k < ErbardRules.slots; k++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: defend
                    ? (k < ErbardRules.slots - broken.length ? AppColors.goldBright : const Color(0x55FFFFFF))
                    : (broken.contains(k) ? const Color(0xFFFF8A65) : const Color(0x55FFFFFF)),
              ),
            ),
        ]),
      );
}

/// 영지 한 곳 (주인 · 다섯 자리 · 할 수 있는 일) → 'fight' · 'hunt' · 'garrison'
Future<String?> showEstateSheet(BuildContext context, AppController c, EstateInfo e) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        final v = c.erbard;
        final o = v.owners[e.id];
        final p = e.province == null ? null : ErbardRules.province(e.province!);
        final kind = c.erbardFightKind(e);
        final broken = o == null ? v.wild[e.id] ?? const <int>[] : v.run[e.id] ?? const <int>[];
        final mine = o?.kind == 'mine';
        final monster = p == null ? MonsterId.blackCaptain : (e.inner ? p.inner : p.outer);
        // 묶음 69 #279: 공성전이 닫혀 있으면 둘러보기만 (수비대 · 공성 · 영지 관리 숨김)
        final open = v.open;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              key: Key('estateSheet_${e.id}'),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Image.asset(ErbardRules.estateIcon(e), width: 56, height: 56, errorBuilder: (_, __, ___) => const SizedBox(width: 56)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, style: AppText.title(19)),
                      Text(e.royal ? '에르바르드 가운데 · 영지 두 곳을 가진 길드만 공성' : '${p!.name} · ${p.element} · ${e.inner ? '안쪽(강함)' : '바깥(보통)'}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  if (o != null) PartyFlag(emblem: o.emblem, color: o.color, size: 36, npc: o.kind == 'npc', crown: o.crown),
                  if (o != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        o == null
                            ? '빈 영지 · 야생 수비대가 지켜요'
                            : switch (o.kind) {
                                'mine' => '우리 길드 영지',
                                'ally' => '연맹 길드 「${o.name}」의 영지',
                                'npc' => '흑등 연맹이 쥐고 있어요',
                                _ => '「${o.name}」 길드의 영지',
                              },
                        style: TextStyle(color: mine ? AppColors.goldBright : AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                if (!mine && open)
                  Row(children: [
                    MonsterPicture(
                        monster: o == null ? monster : (o.kind == 'npc' ? ErbardRules.blackOf(e, 0) : MonsterId.cloneWarrior), size: 44),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o == null ? '야생 수비대 다섯 자리' : '수비대 다섯 자리', style: const TextStyle(color: AppColors.text, fontSize: 13)),
                        const SizedBox(height: 3),
                        _Dots(broken: broken),
                      ]),
                    ),
                  ]),
                // 묶음 65: 엿보기 (주 직업 · 함께 선 동료 수, 능력치 숨김) · 상성 한 줄
                if (!mine && o != null && o.kind != 'ally' && c.erbardGuild && open) _PeekRow(controller: c, estate: e),
                const SizedBox(height: 6),
                if (!open)
                  const Padding(
                    key: Key('estateClosed'),
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(ErbardRules.closedLine,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                if (open)
                  KText(
                      o == null
                          ? (c.erbardGuild
                              ? '공성권 한 장으로 한 자리와 싸워요. 길드원이 나눠서 다섯 자리를 모두 깨면 우리 길드가 차지해요.'
                              : '공성권 한 장으로 한 자리와 싸워요. 다섯 자리를 모두 깨면 개척 보상을 받아요. 영지는 길드만 가질 수 있어 빈 채로 남아요.')
                          : mine
                              ? '길드원이 자기 분신을 세워 지켜요. 두 주 동안 함께 걸을수록 수비대가 튼튼해져요.'
                              : '깃발 공성전 기간에 공성권으로 한 자리씩 깨요. 깬 자리는 공성전 동안 되살아나지 않아요.',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 10),
                if (!open)
                  const SizedBox.shrink()
                else if (kind != null)
                  GoldButton(
                    key: const Key('estateFight'),
                    label: kind == 'wild' ? '야생 수비대와 싸우기' : '공성하기',
                    leading: Image.asset(ErbardRules.ticketImage, width: 24, errorBuilder: (_, __, ___) => const SizedBox()),
                    height: 46,
                    fontSize: 17,
                    onPressed: c.siegeTickets > 0 && !c.erbardBusy ? () => Navigator.pop(sheet, 'fight') : null,
                  )
                else if (!mine)
                  Text(
                      e.royal && o?.kind == 'npc' && !v.active
                          ? '왕성은 깃발 공성전 기간에만 공성할 수 있어요'
                          : o?.kind == 'ally'
                              ? '연맹 길드의 영지는 공성하지 않아요'
                              : c.erbardGuild
                                  ? '깃발 공성전 기간에 공성할 수 있어요 · ${siegeLine(v, c.now)}'
                                  : '주인 있는 영지는 길드끼리 공성전으로 다퉈요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                // 묶음 65: 집결 깃발 (길드장 · 부길드장, 공성전 동안)
                if (v.active && v.staff && !mine && o?.kind != 'ally' && c.erbardGuild) ...[
                  const SizedBox(height: 6),
                  FrameButton(
                    key: const Key('estateRally'),
                    label: v.rally?.estate == e.id ? '집결 깃발이 꽂혀 있어요' : '여기에 집결 깃발 꽂기',
                    height: 42,
                    onPressed: v.rally?.estate == e.id ? null : () => Navigator.pop(sheet, 'rally'),
                  ),
                ],
                if (mine && c.garrisonOpen && open) ...[
                  const SizedBox(height: 6),
                  FrameButton(
                      key: const Key('estateGarrison'),
                      label: '수비대 보기 · 세우기',
                      height: 44,
                      onPressed: () => Navigator.pop(sheet, 'garrison')),
                ],
                // 묶음 65 #255: 영지 관리 (시설 · 특산물 · 번영도 · 정책 · 주민 의뢰)
                if (mine && open) ...[
                  const SizedBox(height: 6),
                  FrameButton(key: const Key('estateManage'), label: '영지 관리', height: 44, onPressed: () => Navigator.pop(sheet, 'manage')),
                ],
                if (!e.royal) ...[
                  const SizedBox(height: 6),
                  FrameButton(
                    key: const Key('estateHunt'),
                    label: '이 영지에서 사냥하기 (여정 기력)',
                    height: 42,
                    onPressed: c.canErbardHunt(e) ? () => Navigator.pop(sheet, 'hunt') : null,
                  ),
                ],
              ]),
            ),
          ),
        );
      },
    );

/// 엿보기 한 줄: 다섯 자리 그림 · 동료 수 · 깬 자리 · 흔들린 자리, 상성 한 줄
class _PeekRow extends StatefulWidget {
  const _PeekRow({required this.controller, required this.estate});
  final AppController controller;
  final EstateInfo estate;

  @override
  State<_PeekRow> createState() => _PeekRowState();
}

class _PeekRowState extends State<_PeekRow> {
  List<PeekSlot>? _slots;

  @override
  void initState() {
    super.initState();
    // 그리는 중에 컨트롤러가 알리지 않게 한 박자 뒤에
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.peekEstate(widget.estate.id).then((s) {
        if (mounted) setState(() => _slots = s);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _slots;
    if (s == null || s.isEmpty) return const SizedBox(height: 4);
    final next = s.where((x) => !x.broken).firstOrNull;
    final m = next?.monster;
    final line = m == null ? null : widget.controller.weakLine(m);
    return Padding(
      key: const Key('estatePeek'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (final (k, x) in s.indexed)
            Expanded(
              child: Opacity(
                opacity: x.broken ? 0.35 : 1,
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    x.monster == null
                        ? const SizedBox(width: 38, height: 38, child: Icon(Icons.shield_outlined, color: AppColors.textMuted))
                        : MonsterPicture(monster: x.monster!, size: 38),
                    if (x.weak)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Image.asset(ErbardRules.ramIcon,
                            width: 18,
                            errorBuilder: (_, __, ___) => const Icon(Icons.hardware_rounded, size: 14, color: Color(0xFFFF8A65))),
                      ),
                  ]),
                  Text(
                      x.broken
                          ? '깸'
                          : x.kind == 'clone' && x.allies > 0
                              ? '${k + 1} · 동료 ${x.allies}'
                              : '${k + 1}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                ]),
              ),
            ),
        ]),
        if (line != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, key: const Key('peekWeak'), style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ),
      ]),
    );
  }
}
