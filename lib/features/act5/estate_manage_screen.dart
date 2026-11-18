import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';

/// 묶음 65 #255 영지 관리: 번영도 · 시설 · 영주의 정책 · 주민 의뢰 · 길드 창고(특산물) · 재료 기부
class EstateManageScreen extends StatefulWidget {
  const EstateManageScreen({super.key, required this.controller, required this.estate});

  final AppController controller;
  final EstateInfo estate;

  @override
  State<EstateManageScreen> createState() => _EstateManageScreenState();
}

class _EstateManageScreenState extends State<EstateManageScreen> {
  AppController get c => widget.controller;
  EstateInfo get e => widget.estate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.refreshEstateDev();
    });
  }

  void _say(String t, {bool ok = true}) => showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  Future<void> _run(Future<bool> f, String done) async {
    final ok = await f;
    if (!mounted) return;
    ok ? _say(done) : _say(c.estateErrorText(), ok: false);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('estateManage'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final v = c.estateDev;
            final d = v?.of(e.id);
            return ListView(
              padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
              children: [
                OrnateTopBar(title: '영지 관리', onBack: () => Navigator.of(context).pop()),
                const SizedBox(height: 6),
                if (v == null || d == null)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  )
                else ...[
                  _header(d),
                  const SizedBox(height: 10),
                  _facilities(v, d),
                  const SizedBox(height: 10),
                  _policy(v, d),
                  const SizedBox(height: 10),
                  _request(v, d),
                  const SizedBox(height: 10),
                  _store(v),
                  const SizedBox(height: 10),
                  _donate(v),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────── 번영도

  Widget _header(EstateDev d) => OrnatePanel(
        key: const Key('estateProsperity'),
        ornament: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Transform.scale(
              scale: EstateDevRules.iconScale(d.stage),
              child: Image.asset(ErbardRules.estateIcon(e), width: 52, height: 52, errorBuilder: (_, __, ___) => const SizedBox(width: 52)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: AppText.title(19)),
                Text('${EstateDevRules.stages[d.stage]} · 시설 칸 ${d.built} / ${d.slots}',
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('번영도', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(child: GlowBar(ratio: d.progress, colors: BarColors.gauge, height: 8)),
            const SizedBox(width: 8),
            Text(d.stage + 1 < EstateDevRules.stages.length ? '다음 · ${EstateDevRules.stages[d.stage + 1]}' : '가장 큰 도시',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          const KText('이 영지에서 사냥하고, 재료를 기부하고, 주민 의뢰를 함께 걸으면 번영도가 올라요. 번영할수록 특산물이 많이 나고 시설 칸이 늘어나요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
        ]),
      );

  // ───────────── 시설

  Widget _facilities(EstateDevView v, EstateDev d) {
    final kinds = EstateDevRules.buildable(e);
    final full = d.built >= d.slots;
    return OrnatePanel(
      key: const Key('estateFacilities'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('시설', style: AppText.title(18)),
          const Spacer(),
          Text('길드 금고 · 금화 ${comma(v.treasury)}', style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        Text('기부 재료 ${comma(v.matPool)}개', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        for (final k in kinds) _facRow(v, d, k, full),
        if (v.siege)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('공성전 중에는 시설을 지을 수 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _facRow(EstateDevView v, EstateDev d, String k, bool full) {
    final f = EstateDevRules.facility(k);
    final lv = d.fac[k] ?? 0;
    final maxed = lv >= EstateDevRules.maxLevel;
    final can = v.staff && !v.siege && !maxed && (lv > 0 || !full);
    final gold = !maxed && lv < v.buildGold.length ? v.buildGold[lv] : 0;
    final mats = !maxed && lv < v.buildMats.length ? v.buildMats[lv] : 0;
    return Container(
      key: Key('fac_$k'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: lv > 0 ? const Color(0x33E9C46A) : const Color(0x22000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: lv > 0 ? 0.6 : 0.25)),
      ),
      child: Row(children: [
        Opacity(
          opacity: lv > 0 ? 1 : 0.45,
          child: Image.asset(f.image, width: 46, height: 46, errorBuilder: (_, __, ___) => const Icon(Icons.home_work_rounded, size: 40, color: AppColors.gold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(f.name, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              for (var i = 0; i < EstateDevRules.maxLevel; i++)
                Icon(i < lv ? Icons.star_rounded : Icons.star_outline_rounded, size: 14, color: AppColors.goldBright),
            ]),
            Text(f.line, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            if (!maxed && v.staff)
              Text('금화 ${comma(gold)} · 기부 재료 $mats개', style: const TextStyle(color: AppColors.goldBright, fontSize: 11)),
          ]),
        ),
        if (v.staff && !maxed)
          TextButton(
            key: Key('facBuild_$k'),
            style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, 34))),
            onPressed: can ? () => _run(c.buildFacility(e.id, k), lv > 0 ? '${f.name}을 ${lv + 1}단계로 올렸어요' : '${f.name}을 지었어요') : null,
            child: Text(lv > 0 ? '올리기' : '짓기', style: const TextStyle(fontSize: 13)),
          ),
      ]),
    );
  }

  // ───────────── 영주의 정책

  Widget _policy(EstateDevView v, EstateDev d) => OrnatePanel(
        key: const Key('estatePolicy'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('영주의 정책', style: AppText.title(18)),
          KText(
              d.canPolicy && v.staff
                  ? '공성전이 끝났어요. 이 영지의 정책을 하나 골라요. 다음 공성전이 끝날 때까지 바꿀 수 없어요.'
                  : '공성전이 끝나면 길드장 · 부길드장이 영지마다 하나 골라요. 고르지 않으면 풍요예요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 8),
          Row(children: [
            for (final p in EstateDevRules.policies)
              Expanded(
                child: GestureDetector(
                  key: Key('policy_${p.id}'),
                  onTap: d.canPolicy && v.staff ? () => _run(c.setEstatePolicy(e.id, p.id), '정책을 「${p.name}」으로 정했어요') : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: p.id == d.policy ? const Color(0x55E9C46A) : const Color(0x22000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.id == d.policy ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.25), width: p.id == d.policy ? 2 : 1),
                    ),
                    child: Column(children: [
                      Image.asset(p.image, width: 44, height: 44, errorBuilder: (_, __, ___) => const Icon(Icons.gavel_rounded, color: AppColors.gold)),
                      const SizedBox(height: 4),
                      Text(p.name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(p.line, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.3)),
                    ]),
                  ),
                ),
              ),
          ]),
        ]),
      );

  // ───────────── 주민 의뢰

  Widget _request(EstateDevView v, EstateDev d) => OrnatePanel(
        key: const Key('estateRequest'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('주민 의뢰', style: AppText.title(18)),
          // 묶음 66: 걸음은 「지금 돕는 영지」 한 곳에만
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(key: const Key('estateHelp'), children: [
              Icon(v.help == e.id ? Icons.volunteer_activism_rounded : Icons.volunteer_activism_outlined,
                  size: 16, color: v.help == e.id ? AppColors.goldBright : AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    v.help == e.id ? '지금 돕는 영지예요 · 길드원 걸음이 이 의뢰에 들어가요' : '지금 돕는 영지 · ${ErbardRules.estate(v.help ?? '')?.name ?? '-'}',
                    style: TextStyle(color: v.help == e.id ? AppColors.goldBright : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (v.staff && v.help != e.id)
                TextButton(
                  key: const Key('estateHelpHere'),
                  onPressed: () => _run(c.setHelpEstate(e.id), '이제 ${e.name} 주민 의뢰를 도와요'),
                  child: const Text('이 영지 돕기', style: TextStyle(fontSize: 12.5)),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text('「${d.request.title}」', style: const TextStyle(color: AppColors.goldBright, fontSize: 14.5, fontWeight: FontWeight.w800)),
          Text('길드원이 함께 ${comma(d.request.goal)}보', style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
          const SizedBox(height: 6),
          GlowBar(ratio: d.request.ratio.clamp(0.0, 1.0), colors: BarColors.gauge, height: 8),
          const SizedBox(height: 4),
          Text(
              d.request.mine > 0
                  ? '나도 ${comma(d.request.mine)}보 함께 걸었어요 · ${d.request.people}명이 함께하는 중'
                  : (v.help == e.id ? '걸으면 이 영지 의뢰에 함께 들어가요' : '돕는 영지로 고르면 걸음이 이 의뢰에 들어가요'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          const KText('다 걸으면 영지가 번영하고, 함께 걸은 길드원에게 주민이 고마움을 보내요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        ]),
      );

  // ───────────── 길드 창고 (특산물)

  Widget _store(EstateDevView v) => OrnatePanel(
        key: const Key('estateStore'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('길드 창고 · 특산물', style: AppText.title(18)),
            const Spacer(),
            Text('오늘 ${v.takeLeft}개 더', style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
          const KText('특산 시설이 있는 영지에서 날마다 길드 창고로 와요. 길드원마다 하루 몇 개씩 받아요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          const SizedBox(height: 6),
          if (v.store.values.every((n) => n <= 0))
            const Text('아직 창고가 비어 있어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
          else
            for (final m in EstateDevRules.specialties)
              if ((v.store[m] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(key: Key('store_${m.name}'), children: [
                    Image.asset(Materials.info(m).asset, width: 36, height: 36, errorBuilder: (_, __, ___) => const SizedBox(width: 36)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${Materials.info(m).name} · ${v.store[m]}개', style: const TextStyle(color: AppColors.text, fontSize: 13.5))),
                    TextButton(
                      key: Key('take_${m.name}'),
                      style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, 32))),
                      onPressed: v.takeLeft > 0
                          ? () async {
                              final got = await c.takeSpecialty(m);
                              if (!mounted) return;
                              got == null ? _say(c.estateErrorText(), ok: false) : _say('${Materials.info(m).name}을 받았어요');
                            }
                          : null,
                      child: const Text('받기', style: TextStyle(fontSize: 13)),
                    ),
                  ]),
                ),
        ]),
      );

  // ───────────── 재료 기부

  Widget _donate(EstateDevView v) {
    final mats = c.donatableMats.take(6).toList();
    return OrnatePanel(
      key: const Key('estateDonate'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('재료 기부', style: AppText.title(18)),
          const Spacer(),
          Text('오늘 ${v.donateLeft}개 더', style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
        const KText('기부한 재료로 시설을 지어요. 기부하면 이 영지의 번영도도 올라요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        const SizedBox(height: 6),
        if (mats.isEmpty)
          const Text('기부할 재료가 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
        else
          for (final (m, n) in mats)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Image.asset(Materials.info(m).asset, width: 32, height: 32, errorBuilder: (_, __, ___) => const SizedBox(width: 32)),
                const SizedBox(width: 8),
                Expanded(child: Text('${Materials.info(m).name} · $n개', style: const TextStyle(color: AppColors.text, fontSize: 13))),
                for (final k in [1, 5])
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton(
                      key: Key('donate_${m.name}_$k'),
                      style: gameButtonStyle(gold: false).copyWith(minimumSize: const WidgetStatePropertyAll(Size(48, 30))),
                      onPressed: n >= k && v.donateLeft >= k ? () => _run(c.donateEstate(e.id, {m: k}), '${Materials.info(m).name} $k개를 기부했어요') : null,
                      child: Text('+$k', style: const TextStyle(fontSize: 12.5)),
                    ),
                  ),
              ]),
            ),
      ]),
    );
  }
}
