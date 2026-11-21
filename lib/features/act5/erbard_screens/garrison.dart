part of '../erbard_screens.dart';

/// 수비대: 우리 영지 다섯 자리 · 내 분신(+ 동료 둘) 세우기
class GarrisonScreen extends StatefulWidget {
  const GarrisonScreen({super.key, required this.controller, required this.estate});

  final AppController controller;
  final EstateInfo estate;

  @override
  State<GarrisonScreen> createState() => _GarrisonScreenState();
}

class _GarrisonScreenState extends State<GarrisonScreen> {
  AppController get c => widget.controller;
  late EstateInfo _e = widget.estate;
  final Set<String> _allies = {};

  void _say(String t, {bool ok = true}) => showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('garrison'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final v = c.erbard;
            final slots = v.garrisons[_e.id] ?? List.filled(ErbardRules.slots, null);
            return ListView(
              padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
              children: [
                OrnateTopBar(title: '수비대', onBack: () => Navigator.of(context).pop()),
                if (v.myEstates.length > 1)
                  Wrap(spacing: 6, children: [
                    for (final id in v.myEstates)
                      ChoiceChip(
                        key: Key('garrisonEstate_$id'),
                        label: Text(ErbardRules.estate(id)!.name),
                        selected: id == _e.id,
                        onSelected: (_) => setState(() => _e = ErbardRules.estate(id)!),
                      ),
                  ]),
                const SizedBox(height: 8),
                OrnatePanel(
                  ornament: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Image.asset(ErbardRules.estateIcon(_e),
                          width: 48, height: 48, errorBuilder: (_, __, ___) => const SizedBox(width: 48)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_e.name, style: AppText.title(18))),
                    ]),
                    const SizedBox(height: 4),
                    KText(v.active ? '공성전 중에는 수비대를 바꿀 수 없어요.' : '길드원마다 한 자리에 자기 분신을 세워요. 동료는 둘까지 함께 서요. 두 주 동안 길드원이 함께 걸을수록 튼튼해져요.',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 8),
                    for (var k = 0; k < ErbardRules.slots; k++) _slot(v, k, k < slots.length ? slots[k] : null),
                  ]),
                ),
                if (v.active && v.gauge != null) ...[
                  const SizedBox(height: 10),
                  _repair(v),
                ],
                const SizedBox(height: 10),
                _boost(v),
                const SizedBox(height: 10),
                OrnatePanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('함께 서는 동료 (둘까지)', style: AppText.title(15)),
                    const SizedBox(height: 6),
                    if (c.allies.isEmpty)
                      const Text('3막에서 만난 동료가 없어요', style: TextStyle(color: AppColors.textMuted))
                    else
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final a in c.allies)
                          FilterChip(
                            key: Key('garrisonAlly_${a.id}'),
                            label: Text('${a.name} Lv.${a.level}'),
                            selected: _allies.contains(a.id),
                            onSelected: (on) => setState(() {
                              if (on && _allies.length < ErbardRules.garrisonAllies) {
                                _allies.add(a.id);
                              } else {
                                _allies.remove(a.id);
                              }
                            }),
                          ),
                      ]),
                    if (v.placed != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('garrisonRemove'),
                        onPressed: v.active || c.erbardBusy
                            ? null
                            : () async {
                                final ok = await c.removeGarrison();
                                if (mounted) ok ? _say('내 분신을 내렸어요') : _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
                              },
                        child: const Text('내 분신 내리기', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 묶음 65: 성벽 보수 (공성전 동안 길드 걸음 게이지, 영지마다 한 번 · 길드장 · 부길드장이 고름)
  Widget _repair(ErbardView v) {
    final g = v.gauge!;
    final done = g.repairs.contains(_e.id);
    return OrnatePanel(
      key: const Key('garrisonRepair'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Image.asset(ErbardRules.repairIcon,
              width: 26, errorBuilder: (_, __, ___) => const Icon(Icons.construction_rounded, color: AppColors.goldBright)),
          const SizedBox(width: 6),
          Expanded(child: Text('성벽 보수', style: AppText.title(15))),
          Text(
              done
                  ? '이번 공성전 보수함'
                  : g.power > 0
                      ? '쓸 수 있는 힘 ${g.power}'
                      : '',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        SiegeGaugeRow(gauge: g, mine: v.myEstates.length),
        const SizedBox(height: 4),
        const KText('공성전 동안 길드원이 걸은 걸음으로 게이지가 차면 힘이 모여요. 길드장 · 부길드장이 그 힘으로 우리 영지의 깨진 자리 하나를 되살려요. 영지마다 공성전에 한 번이에요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        if (v.staff && !done)
          TextButton(
            key: const Key('garrisonRepairHere'),
            onPressed: c.erbardBusy || g.power <= 0 || (v.defense[_e.id] ?? 0) <= 0
                ? null
                : () async {
                    final ok = await c.usePower('repair', estate: _e.id);
                    if (mounted) ok ? _say('${_e.name}의 성벽을 보수했어요') : _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
                  },
            child: Text(g.power > 0 ? '모인 힘으로 이 영지 성벽 보수하기' : '게이지가 차면 성벽을 보수할 수 있어요'),
          ),
      ]),
    );
  }

  /// 묶음 61: 길드 금고로 수비대 강화 (그 영지 · 다음 공성전 끝까지, 세기는 숨김)
  Widget _boost(ErbardView v) {
    final cur = v.boosts[_e.id] ?? 0;
    return OrnatePanel(
      key: const Key('garrisonBoost'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('수비대 강화 · 길드 금고', style: AppText.title(15)),
          const Spacer(),
          for (var i = 1; i <= ErbardRules.boostCost.length; i++)
            Icon(i <= cur ? Icons.shield_rounded : Icons.shield_outlined, size: 18, color: AppColors.goldBright),
        ]),
        const SizedBox(height: 4),
        KText(cur > 0 ? '금고 금화로 단단해진 수비대예요. 다음 공성전이 끝날 때까지 이어져요.' : '길드장 · 부길드장이 금고 금화로 이 영지 수비대를 더 단단하게 해요. 다음 공성전이 끝날 때까지 이어져요.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
        Text('길드 금고 · 금화 ${comma(v.treasury)}',
            key: const Key('garrisonTreasury'), style: const TextStyle(color: AppColors.text, fontSize: 13)),
        if (v.staff) ...[
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 1; i <= ErbardRules.boostCost.length; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: FrameButton(
                  key: Key('garrisonBoost_$i'),
                  label: '$i단계 · ${comma(ErbardRules.boostCost[i - 1] - (cur > 0 && cur < i ? ErbardRules.boostCost[cur - 1] : 0))}',
                  height: 40,
                  onPressed: v.active || c.guildBusy || i <= cur
                      ? null
                      : () async {
                          final ok = await c.boostGarrison(_e.id, i);
                          if (mounted) ok ? _say('수비대를 강화했어요') : _say(GuildRules.errorText(c.guildError ?? ''), ok: false);
                        },
                ),
              ),
            ],
          ]),
          if (v.active) const Text('공성전 중에는 강화할 수 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _slot(ErbardView v, int k, ({String name, int level, List<String> allies, bool me})? g) => Container(
        key: Key('garrisonSlot_$k'),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: g?.me ?? false ? const Color(0x33E8C46A) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x44E8C46A)),
        ),
        child: Row(children: [
          Text('${k + 1}', style: AppText.title(15, color: AppColors.goldBright)),
          const SizedBox(width: 6),
          if (g != null) ...[
            MonsterPicture(monster: ErbardRules.cloneOf((v.guards[_e.id] ?? const []).elementAtOrNull(k)), size: 36),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          Expanded(
            child: g == null
                ? const Text('빈 자리 · 비어 있으면 그 지방 수비병이 지켜요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${g.name}${g.me ? ' (나)' : ''} · Lv.${g.level}',
                        style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    if (g.allies.isNotEmpty)
                      Text('함께: ${g.allies.join(' · ')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
          ),
          if (!v.active && (g == null || g.me))
            FilledButton(
              key: Key('garrisonPlace_$k'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, minimumSize: const Size(0, 32)),
              onPressed: c.erbardBusy
                  ? null
                  : () async {
                      final ok = await c.placeGarrison(_e.id, k, _allies.toList());
                      if (!mounted) return;
                      ok ? _say('${_e.name} ${k + 1}번 자리에 섰어요') : _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
                    },
              child: Text(g == null ? '여기 서기' : '다시 서기', style: const TextStyle(color: AppColors.goldInk)),
            ),
        ]),
      );
}

/// 연맹: 만들기 · 코드로 들어가기 · 나가기 (길드장)
Future<void> showAllianceSheet(BuildContext context, AppController c) {
  final name = TextEditingController();
  final code = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final v = c.erbard;
        final a = v.alliance;
        void err() => showTopNotice(context, ErbardRules.errorText(c.erbardError ?? ''), icon: Icons.info_outline_rounded);
        return SafeArea(
          child: Padding(
            key: const Key('allianceSheet'),
            padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('연맹', style: AppText.title(18)),
              const Text('길드 세 곳까지 함께해요. 연맹 길드끼리는 서로 공성하지 않고, 영지 몫 보상을 나눠요. 연맹은 공성전 네 번마다 다시 고를 수 있어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 10),
              if (a != null) ...[
                Text(a.name, style: AppText.title(17, color: AppColors.goldBright)),
                Text(a.guilds.join(' · '), style: const TextStyle(color: AppColors.text)),
                Row(children: [
                  Text('연맹 코드 ${a.code}', style: const TextStyle(color: AppColors.textMuted)),
                  IconButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: a.code)),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
                  ),
                ]),
                if (v.owner)
                  TextButton(
                    key: const Key('allianceLeave'),
                    onPressed: a.locked
                        ? null
                        : () async {
                            if (!await c.allianceAction('leave')) err();
                          },
                    child: Text(a.locked ? '공성전 네 번이 지나면 다시 고를 수 있어요' : '연맹에서 나가기', style: const TextStyle(color: AppColors.textMuted)),
                  ),
              ] else if (!v.owner)
                const Text('연맹은 길드장이 만들거나 들어가요', style: TextStyle(color: AppColors.textMuted))
              else ...[
                TextField(
                  key: const Key('allianceName'),
                  controller: name,
                  maxLength: 12,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(hintText: '연맹 이름', counterText: '', isDense: true),
                ),
                const SizedBox(height: 6),
                GoldButton(
                  key: const Key('allianceCreate'),
                  label: '연맹 만들기',
                  height: 44,
                  fontSize: 17,
                  onPressed: () async {
                    if (name.text.trim().length < 2) return;
                    if (!await c.allianceAction('create', name: name.text.trim())) err();
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const Key('allianceCode'),
                      controller: code,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: AppColors.text, letterSpacing: 3),
                      decoration: const InputDecoration(hintText: '연맹 코드', counterText: '', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('allianceJoin'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: () async {
                      if (code.text.trim().length < 6) return;
                      if (!await c.allianceAction('join', code: code.text.trim().toUpperCase())) err();
                    },
                    child: const Text('들어가기', style: TextStyle(color: AppColors.goldInk)),
                  ),
                ]),
              ],
            ]),
          ),
        );
      },
    ),
  );
}
