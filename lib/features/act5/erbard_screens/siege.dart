part of '../erbard_screens.dart';

/// 지난 공성전 결과 (일요일 밤 정리 뒤 한 번 · 지도에서 다시 보기)
class SiegeResultScreen extends StatefulWidget {
  const SiegeResultScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SiegeResultScreen> createState() => _SiegeResultScreenState();
}

class _SiegeResultScreenState extends State<SiegeResultScreen> {
  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.markSiegeResultSeen();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final v = c.erbard;
    final no = v.lastNo ?? 0;
    return Scaffold(
      key: const Key('siegeResult'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FrameButton(key: const Key('siegeResultClose'), label: '확인', onPressed: () => Navigator.of(context).pop()),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: pad.bottom + 16),
        children: [
          SizedBox(
            height: 220 + pad.top,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(ErbardRules.siegeBg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.night)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x330B0D26), Color(0xFF0B0D26)]),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('제${no + 1}회 깃발 공성전', style: AppText.title(24, color: AppColors.goldBright)),
                  Text(v.lastRoyalNpc ? '왕성은 아직 흑등 연맹이 쥐고 있어요' : '에르바르드 왕성은 「${v.lastRoyal}」 길드가 지켜요',
                      style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: OrnatePanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('주인이 바뀐 영지', style: AppText.title(15)),
                const SizedBox(height: 6),
                if (v.lastChanges.isEmpty) const Text('이번엔 주인이 바뀐 영지가 없어요', style: TextStyle(color: AppColors.textMuted)),
                for (final ch in v.lastChanges)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(ErbardRules.estate(ch.estate)?.name ?? ch.estate,
                            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                      ),
                      Text('${ch.fromName.isEmpty ? '빈 영지' : ch.fromName} → ${ch.toName}',
                          style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                    ]),
                  ),
                const SizedBox(height: 8),
                if (c.erbardGuild)
                  Text(
                      v.myEstates.isEmpty
                          ? '우리 길드 영지 없음 · 다음 공성전에 다시 도전해요'
                          : '우리 길드 영지 ${v.myEstates.length}곳 · ${v.myEstates.map((x) => ErbardRules.estate(x)?.name ?? x).join(' · ')}',
                      style: const TextStyle(color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('공성전 보상은 세라 이름으로 우편에 왔어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 공성 망치 · 성벽 보수 게이지 한 줄 (걸음 숫자 · 게이지 크기는 숨김)
class SiegeGaugeRow extends StatelessWidget {
  const SiegeGaugeRow({super.key, required this.gauge, required this.mine});

  final SiegeGauge gauge;

  /// 우리 영지 수 (성벽 보수는 영지마다 한 번)
  final int mine;

  @override
  Widget build(BuildContext context) {
    Widget icon(String a, IconData f) =>
        Image.asset(a, width: 22, height: 22, errorBuilder: (_, __, ___) => Icon(f, size: 18, color: AppColors.goldBright));
    return Row(key: const Key('siegeGauge'), children: [
      icon(ErbardRules.ramIcon, Icons.hardware_rounded),
      const SizedBox(width: 4),
      Text('${gauge.rams}/${gauge.ramMax}', style: const TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
      const SizedBox(width: 8),
      icon(ErbardRules.repairIcon, Icons.construction_rounded),
      const SizedBox(width: 4),
      Text('${gauge.repairs.length}/$mine', style: const TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: gauge.progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: const Color(0x33FFFFFF),
              color: const Color(0xFFFF8A65)),
        ),
      ),
    ]);
  }
}

/// 묶음 66: 쓸 수 있는 힘 · 공성 망치 / 성벽 보수 고르기 (길드장 · 부길드장)
class SiegePowerPanel extends StatelessWidget {
  const SiegePowerPanel({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final v = c.erbard;
    final g = v.gauge;
    if (g == null) return const SizedBox.shrink();
    Future<void> use(String kind) async {
      final ok = await c.usePower(kind);
      if (!context.mounted) return;
      showTopNotice(context, ok ? (kind == 'ram' ? '공성 망치를 썼어요' : '성벽을 보수했어요') : ErbardRules.errorText(c.erbardError ?? ''),
          icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);
    }

    final canRam = v.staff && g.power > 0 && g.rams < g.ramMax && v.rally != null;
    final canRepair = v.staff && g.power > 0 && v.myEstates.any((id) => !g.repairs.contains(id) && (v.defense[id] ?? 0) > 0);
    return Container(
      key: const Key('siegePower'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: g.power > 0 ? const Color(0x33E9C46A) : const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: g.power > 0 ? 0.7 : 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, color: AppColors.goldBright, size: 18),
          const SizedBox(width: 4),
          Text(g.power > 0 ? '쓸 수 있는 힘 ${g.power}' : '게이지가 차면 힘이 모여요',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        if (v.staff) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextButton(
                key: const Key('powerRam'),
                style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36))),
                onPressed: canRam && !c.erbardBusy ? () => use('ram') : null,
                child: Text('공성 망치 ${g.rams}/${g.ramMax}', style: const TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextButton(
                key: const Key('powerRepair'),
                style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 36))),
                onPressed: canRepair && !c.erbardBusy ? () => use('repair') : null,
                child: Text('성벽 보수 ${g.repairs.length}/${v.myEstates.length}', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ]),
          if (v.rally == null && g.power > 0)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('공성 망치는 집결 깃발을 꽂은 영지에 써요', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ),
        ] else if (g.power > 0)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('길드장 · 부길드장이 공성 망치나 성벽 보수에 써요', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ),
      ]),
    );
  }
}

/// 전황판: 우리 영지 남은 자리 · 우리가 치는 영지 · 게이지 · 게시판 소식
Future<void> showWarBoard(BuildContext context, AppController c) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final v = c.erbard;
          Widget dots(int broken, {bool defend = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (var k = 0; k < ErbardRules.slots; k++)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(defend ? (k < ErbardRules.slots - broken ? '●' : '○') : (k < broken ? '●' : '○'),
                        style: TextStyle(color: defend ? AppColors.goldBright : const Color(0xFFFF8A65), fontSize: 13)),
                  ),
              ]);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
              child: ListView(key: const Key('warBoard'), padding: const EdgeInsets.fromLTRB(18, 16, 18, 16), children: [
                Text('전황판 · 제${v.siegeNo + 1}회 깃발 공성전', style: AppText.title(18)),
                Text(siegeLine(v, c.now), style: const TextStyle(color: Color(0xFFFF8A65), fontSize: 12.5, fontWeight: FontWeight.w700)),
                // 묶음 68 #275: 길드 대화 바로가기
                if (c.chatOpen && c.guild?.id != null && !(c.guild?.lian ?? true)) ...[
                  const SizedBox(height: 8),
                  FrameButton(
                    key: const Key('warBoardChat'),
                    label: '길드 대화',
                    height: 40,
                    onPressed: () {
                      final g = c.guild!;
                      Navigator.pop(sheet);
                      openRoom(context, c, 'g_${g.id}', name: '길드 · ${g.name}');
                    },
                  ),
                ],
                if (v.gauge != null) ...[
                  const SizedBox(height: 10),
                  Text('길드 걸음 게이지', style: AppText.title(14)),
                  const SizedBox(height: 4),
                  SiegeGaugeRow(gauge: v.gauge!, mine: v.myEstates.length),
                  const SizedBox(height: 3),
                  const KText(
                      '공성전 동안 길드원이 걸은 걸음이 쌓여요. 가득 차면 힘이 하나 모이고, 길드장 · 부길드장이 공성 망치(집결 깃발 영지의 남은 자리 하나를 흔듦)와 성벽 보수(우리 영지의 깨진 자리 하나를 되살림) 중에 골라 써요. 안 쓴 힘은 공성전이 끝나면 사라져요.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4)),
                  const SizedBox(height: 6),
                  SiegePowerPanel(controller: c),
                ],
                if (v.rally != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Image.asset(ErbardRules.rallyIcon,
                        width: 22, errorBuilder: (_, __, ___) => const Icon(Icons.flag_rounded, color: Color(0xFFFF8A65))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('집결 깃발 · ${ErbardRules.estate(v.rally!.estate)?.name ?? ''}',
                          style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ],
                const SizedBox(height: 10),
                Text('우리 영지', style: AppText.title(14)),
                if (v.myEstates.isEmpty) const Text('아직 영지가 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                for (final id in v.myEstates)
                  Padding(
                    key: Key('warMine_$id'),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                          child: Text(ErbardRules.estate(id)?.name ?? id, style: const TextStyle(color: AppColors.text, fontSize: 13))),
                      if ((v.gauge?.repairs ?? const []).contains(id))
                        const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text('보수함', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                      dots(v.defense[id] ?? 0, defend: true),
                    ]),
                  ),
                const SizedBox(height: 8),
                Text('우리가 치는 영지', style: AppText.title(14)),
                if (v.run.isEmpty) const Text('아직 깬 자리가 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                for (final e in v.run.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                          child:
                              Text(ErbardRules.estate(e.key)?.name ?? e.key, style: const TextStyle(color: AppColors.text, fontSize: 13))),
                      dots(e.value.length),
                    ]),
                  ),
                if (v.news.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('길드 소식', style: AppText.title(14)),
                  for (final n in v.news.take(10))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('· ${n.text}', style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
                    ),
                ],
              ]),
            ),
          );
        },
      ),
    );

/// 결과 장면: 끝난 공성전 뒤 지도를 처음 열 때 깃발이 바뀌는 그림 (새 깃발 자리에 길드 깃발)
class SiegeResultScene extends StatefulWidget {
  const SiegeResultScene({super.key, required this.controller});

  final AppController controller;

  @override
  State<SiegeResultScene> createState() => _SiegeResultSceneState();
}

class _SiegeResultSceneState extends State<SiegeResultScene> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c.erbard;
    final g = c.guild;
    // 우리 길드가 새로 얻은 영지가 있으면 우리 깃발, 아니면 왕성 주인 깃발
    final mine = v.lastChanges.any((x) => v.owners[x.estate]?.kind == 'mine');
    final royal = v.owners['royal'];
    final flag = mine && g != null
        ? PartyFlag(emblem: g.emblem, color: g.color, size: 120, gold: g.goldFlag)
        : royal == null || royal.kind == 'npc'
            ? const PartyFlag(emblem: 0, color: 7, size: 120, npc: true)
            : PartyFlag(emblem: royal.emblem, color: royal.color, size: 120, crown: royal.crown);
    return Scaffold(
      key: const Key('siegeResultScene'),
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final t = _a.value;
            final rise = Curves.easeOutBack.transform(((t - 0.35) / 0.45).clamp(0.0, 1.0));
            return Stack(fit: StackFit.expand, children: [
              Image.asset(ErbardRules.resultScene,
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset(ErbardRules.siegeBg, fit: BoxFit.cover)),
              // 새 깃발 자리 (그림 가운데 위쪽)
              Align(
                alignment: Alignment(0, -0.38 + 0.12 * (1 - rise)),
                child: Opacity(opacity: rise.clamp(0.0, 1.0), child: Transform.scale(scale: 0.6 + 0.4 * rise, child: flag)),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: MediaQuery.paddingOf(context).bottom + 40,
                child: Opacity(
                  opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    // 밝은 하늘 위에서도 글이 또렷하게
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('제${(v.lastNo ?? 0) + 1}회 깃발 공성전이 끝났어요', textAlign: TextAlign.center, style: AppText.title(20)),
                        const SizedBox(height: 6),
                        const Text('화면을 누르면 결과를 봐요', style: TextStyle(color: Color(0xFFE6E0F2), fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
