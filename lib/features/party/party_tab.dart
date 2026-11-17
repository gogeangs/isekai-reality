import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/party_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../battle/battle_view.dart' show MonsterPicture;
import '../settings/account_section.dart' show LoginButton, signInFlow;
import '../town/material_view.dart';
import 'party_boss_screen.dart';
import 'party_flag.dart';

/// 주점 「파티」 탭 (묶음 56 #236): 로그인 안내 · 만들기/들어가기 · 파티(깃발 · 파티원 · 함께 걷기 ·
/// 파티 보스 · 함께 있어요 · 상점). 파티원 위치는 어디에도 보이지 않는다.
class PartyTab extends StatefulWidget {
  const PartyTab({super.key, required this.controller});

  final AppController controller;

  @override
  State<PartyTab> createState() => _PartyTabState();
}

class _PartyTabState extends State<PartyTab> {
  AppController get c => widget.controller;
  final _name = TextEditingController();
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _locationNotice();
    });
  }

  /// 묶음 57: 처음 파티 화면을 열면 위치 안내 한 번
  Future<void> _locationNotice() async {
    if (c.partyNoticeSeen || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('partyLocationNotice'),
        title: const Text('함께 있어요 안내'),
        content: Text(keepAll(LegalRules.partyLocationNotice),
            style: const TextStyle(color: AppColors.text, height: 1.45)),
        actions: [
          TextButton(
              key: const Key('partyLocationOk'),
              onPressed: () => Navigator.pop(d),
              child: const Text('확인')),
        ],
      ),
    );
    await c.markPartyNotice();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await c.refreshParty();
    _notice();
  }

  void _notice() {
    if (!mounted) return;
    final n = c.takePartyNotice();
    if (n != null) showTopNotice(context, n, icon: Icons.favorite_rounded);
  }

  void _err() {
    if (!mounted) return;
    final e = c.partyError;
    if (e != null) showTopNotice(context, PartyRules.errorText(e), icon: Icons.info_outline_rounded);
  }

  Future<void> _run(Future<bool> Function() f, {String? ok}) async {
    final done = await f();
    if (!mounted) return;
    if (done) {
      if (ok != null) showTopNotice(context, ok, icon: Icons.check_circle_rounded);
      _notice();
    } else {
      _err();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.partyReady) return _login();
          final v = c.party;
          if (v == null) {
            return c.partyError != null ? _offline() : _loading();
          }
          if (v.restricted) return _note(PartyRules.restrictedLine, key: 'partyRestricted');
          if (!v.inParty) return _start();
          return _party(v);
        },
      );

  Widget _note(String line, {String? key, Widget? child}) => OrnatePanel(
        key: key == null ? null : Key(key),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.groups_rounded, color: AppColors.goldBright, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: KText(line,
                  style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)),
            ),
          ]),
          if (child != null) ...[const SizedBox(height: 12), child],
        ]),
      );

  Widget _login() => _note(PartyRules.loginLine,
      key: 'partyLogin',
      child: c.cloudAvailable
          ? Column(children: [
              for (final p in c.loginProviders) ...[
                LoginButton(provider: p, busy: c.cloudBusy, onPressed: () => signInFlow(context, c, p)),
                const SizedBox(height: 8),
              ],
            ])
          : const Text('로그인은 준비 중이에요.', style: TextStyle(color: AppColors.textMuted)));

  Widget _loading() => const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: AppColors.goldBright)),
      );

  Widget _offline() => _note(PartyRules.offlineLine,
      key: 'partyOffline',
      child: FrameButton(label: '다시 불러오기', height: 44, onPressed: _refresh));

  // ───────────── 파티가 없을 때: 만들기 · 초대 코드로 들어가기

  Widget _start() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _note(PartyRules.noPartyLine, key: 'partyStart'),
        const SizedBox(height: 10),
        OrnatePanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('파티 만들기', style: AppText.title(16)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('partyNameField'),
              controller: _name,
              maxLength: 12,
              style: const TextStyle(color: AppColors.text),
              decoration: InputDecoration(
                hintText: '${c.profile.name}의 파티',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            GoldButton(
              key: const Key('partyCreate'),
              label: '파티 만들기',
              height: 46,
              fontSize: 18,
              onPressed: c.partyBusy
                  ? null
                  : () => _run(() => c.createParty(_name.text.trim()), ok: '파티를 만들었어요! 초대 코드를 친구에게 보내 보세요'),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        OrnatePanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('초대 코드로 들어가기', style: AppText.title(16)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('partyCodeField'),
              controller: _code,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: AppColors.text, letterSpacing: 4, fontSize: 18),
              decoration: const InputDecoration(
                hintText: '여섯 글자',
                hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 0, fontSize: 14),
                counterText: '',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            FrameButton(
              key: const Key('partyJoin'),
              label: '들어가기',
              height: 46,
              onPressed: c.partyBusy
                  ? null
                  : () {
                      if (_code.text.trim().length < 6) return;
                      _run(() => c.joinParty(_code.text), ok: '파티에 들어갔어요!');
                    },
            ),
          ]),
        ),
      ]);

  // ───────────── 파티

  Widget _party(PartyView v) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(v),
        if (!v.stepsCounted) ...[
          const SizedBox(height: 6),
          const KText(PartyRules.stepsElsewhere,
              key: Key('partyStepsElsewhere'),
              style: TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        _walk(v),
        const SizedBox(height: 10),
        if (v.boss != null) ...[_boss(v), const SizedBox(height: 10)],
        if (v.lastBoss != null) ...[_lastBoss(v), const SizedBox(height: 10)],
        _together(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FrameButton(
              key: const Key('partyShopOpen'),
              label: '파티 상점',
              height: 44,
              onPressed: () => showPartyShop(context, c),
            ),
          ),
          if (v.owner) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FrameButton(
                key: const Key('partyStyleOpen'),
                label: '꾸미기',
                height: 44,
                onPressed: () => _style(v),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('partyLeave'),
          onPressed: () => _leave(v),
          child: const Text('파티 나가기', style: TextStyle(color: AppColors.textMuted)),
        ),
      ]);

  Widget _header(PartyView v) => OrnatePanel(
        key: const Key('partyHeader'),
        ornament: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            PartyFlag(emblem: v.emblem, color: v.color, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.name, key: const Key('partyName'), style: AppText.title(19)),
                const SizedBox(height: 2),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  const Text('초대 코드 ', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  Text(v.code,
                      key: const Key('partyCode'),
                      style: const TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 16,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  InkWell(
                    key: const Key('partyCopy'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: v.code));
                      showTopNotice(context, '초대 코드를 복사했어요', icon: Icons.copy_rounded);
                    },
                    child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted)),
                  ),
                  InkWell(
                    key: const Key('partyShare'),
                    onTap: () => SharePlus.instance
                        .share(ShareParams(text: PartyRules.inviteText(v.name, v.code))),
                    child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.ios_share_rounded, size: 16, color: AppColors.textMuted)),
                  ),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          for (final m in v.members) _member(v, m),
          if (v.members.length < PartyRules.maxMembers)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${PartyRules.maxMembers - v.members.length}자리가 비어 있어요 · 초대 코드를 보내 보세요',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
        ]),
      );

  Widget _member(PartyView v, PartyMember m) {
    final top = v.members.fold<int>(1, (t, x) => x.steps > t ? x.steps : t);
    return Padding(
      key: Key('partyMember_${m.uid}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 18,
          child: m.owner
              ? const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.goldBright)
              : null,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 88,
          child: Text('${m.name}${m.me ? ' (나)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: m.me ? AppColors.goldBright : AppColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700)),
        ),
        Text('Lv.${m.level}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: m.steps / top,
                minHeight: 6,
                backgroundColor: const Color(0x33FFFFFF),
                color: m.me ? AppColors.goldBright : AppColors.gold,
              ),
            ),
            Text('${comma(m.steps)}보',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 6),
        if (!m.me)
          SizedBox(
            width: 36,
            child: m.cheeredToday
                ? const Icon(Icons.favorite_rounded, size: 18, color: AppColors.goldBright)
                : IconButton(
                    key: Key('partyCheer_${m.uid}'),
                    padding: EdgeInsets.zero,
                    tooltip: '응원하기',
                    onPressed: v.canCheer && !c.partyBusy
                        ? () => _run(() => c.cheerMember(m.uid), ok: '${m.name}님을 응원했어요!')
                        : null,
                    icon: Image.asset('assets/images/icon_cheer.webp',
                        width: 26,
                        height: 26,
                        color: v.canCheer ? null : const Color(0x88FFFFFF),
                        colorBlendMode: v.canCheer ? null : BlendMode.modulate,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.favorite_border_rounded, color: AppColors.goldBright)),
                  ),
          )
        else
          const SizedBox(width: 36),
        if (v.owner && !m.me)
          SizedBox(
            width: 28,
            child: IconButton(
              key: Key('partyKick_${m.uid}'),
              padding: EdgeInsets.zero,
              tooltip: '내보내기',
              onPressed: () => _kick(m),
              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
            ),
          ),
      ]),
    );
  }

  Widget _walk(PartyView v) {
    final goals = v.walkGoals;
    final max = goals.isEmpty ? 1 : goals.last;
    return OrnatePanel(
      key: const Key('partyWalk'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.directions_walk_rounded, color: AppColors.goldBright, size: 20),
          const SizedBox(width: 6),
          Text('함께 걷기', style: AppText.title(16)),
          const Spacer(),
          Text('이번 주 ${comma(v.walkTotal)}보',
              key: const Key('partyWalkTotal'),
              style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 2),
        const Text('파티 모두의 걸음을 합쳐요 · 월요일에 새로',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (v.walkTotal / max).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0x33FFFFFF),
            color: AppColors.goldBright,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < goals.length; i++) _tier(v, i),
      ]),
    );
  }

  Widget _tier(PartyView v, int i) {
    final reached = v.walkTotal >= v.walkGoals[i];
    final got = v.walkClaimed.contains(i);
    const names = ['금화 · 발자국 표', '마석 · 재료 꾸러미 · 발자국 표', '파티 상자 · 발자국 표'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Image.asset(i == 2 ? 'assets/images/chest_party.webp' : 'assets/images/item_footTicket.webp',
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.card_giftcard_rounded, color: AppColors.gold, size: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}단계 · ${comma(v.walkGoals[i])}보',
                style: TextStyle(
                    color: reached ? AppColors.goldBright : AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text(names[i], style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
        if (got)
          const Text('받음', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
        else if (!reached)
          Text('${comma((v.walkGoals[i] - v.walkTotal).clamp(0, 1 << 30))}보 더',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
        else
          SizedBox(
            height: 32,
            child: FilledButton(
              key: Key('partyWalkClaim_$i'),
              onPressed: c.partyBusy ? null : () => _claim('walk', tier: i),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold, padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('받기', style: TextStyle(color: AppColors.goldInk, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  Widget _boss(PartyView v) {
    final b = v.boss!;
    final id = PartyRules.bossOf(b.id) ?? MonsterId.partyGolem;
    final info = Monsters.info(id);
    return OrnatePanel(
      key: const Key('partyBoss'),
      ornament: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('이번 주 파티 보스', style: AppText.title(16)),
          const Spacer(),
          if (b.encounter > 1)
            Text('${b.encounter}번째 만남',
                key: const Key('partyBossEncounter'),
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Opacity(opacity: b.defeated ? 0.45 : 1, child: MonsterPicture(monster: id, size: 86)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info.name, style: AppText.title(18)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  key: const Key('partyBossHp'),
                  value: b.left,
                  minHeight: 10,
                  backgroundColor: const Color(0x33FFFFFF),
                  color: const Color(0xFFE25D5D),
                ),
              ),
              const SizedBox(height: 4),
              Text(b.defeated ? '쓰러뜨렸어요!' : '내가 준 피해 ${comma(b.myDamage)}',
                  style: TextStyle(
                      color: b.defeated ? AppColors.goldBright : AppColors.textMuted, fontSize: 12.5)),
              Row(children: [
                Image.asset('assets/images/item_footTicket.webp',
                    width: 16, height: 16, errorBuilder: (_, __, ___) => const SizedBox()),
                const SizedBox(width: 3),
                Text('오늘 도전권 ${b.tickets}장',
                    key: const Key('partyBossTickets'),
                    style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('3,000보마다 도전권 한 장 (하루 3장) · 각자 준 피해가 합쳐져요',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        const SizedBox(height: 8),
        if (b.defeated)
          GoldButton(
            key: const Key('partyBossClaim'),
            label: b.claimed ? '보상을 받았어요' : '보스 보상 받기',
            height: 46,
            fontSize: 17,
            onPressed: b.claimed || b.myDamage <= 0 || c.partyBusy ? null : () => _claim('boss'),
          )
        else
          GoldButton(
            key: const Key('partyBossFight'),
            label: b.tickets > 0 ? '도전하기' : '걸으면 도전권이 생겨요',
            height: 46,
            fontSize: 17,
            onPressed: b.tickets > 0 && !c.partyBusy ? _fight : null,
          ),
      ]),
    );
  }

  Widget _lastBoss(PartyView v) => OrnatePanel(
        key: const Key('partyLastBoss'),
        child: Row(children: [
          const Icon(Icons.history_rounded, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: KText('지난주 보스는 놓쳤지만, 준 피해만큼 발자국 표를 받을 수 있어요',
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
          FilledButton(
            key: const Key('partyLastClaim'),
            onPressed: c.partyBusy ? null : () => _claim('bossLast'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
            child: const Text('받기', style: TextStyle(color: AppColors.goldInk)),
          ),
        ]),
      );

  Widget _together() {
    final near = c.partyNear;
    return OrnatePanel(
      key: const Key('partyTogether'),
      highlight: near,
      child: Row(children: [
        Icon(near ? Icons.people_alt_rounded : Icons.people_outline_rounded,
            color: near ? AppColors.goldBright : AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(near ? '함께 있어요' : '함께 사냥',
                key: Key(near ? 'partyNearOn' : 'partyNearOff'),
                style: AppText.title(15, color: near ? AppColors.goldBright : AppColors.text)),
            KText(
                near
                    ? '파티원이 가까이 있어요. 지금 잡는 몬스터는 경험치와 재료가 조금 더!'
                    : '파티원과 가까이 있으면 잡은 몬스터의 보상이 조금 더 좋아져요. 서로의 위치는 보이지 않아요.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ),
        Column(children: [
          Text('${c.partyLocal.together}',
              key: const Key('partyTogetherCount'),
              style: AppText.title(18, color: AppColors.goldBright)),
          const Text('함께 잡은\n몬스터',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.1)),
        ]),
      ]),
    );
  }

  // ───────────── 동작

  Future<void> _claim(String kind, {int? tier}) async {
    final got = await c.claimParty(kind, tier: tier);
    if (!mounted) return;
    if (got == null) return _err();
    await showDialog<void>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('받았어요!'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(
              got.any((g) => g.startsWith('금빛 상자'))
                  ? 'assets/images/chest_partyGold.webp'
                  : got.any((g) => g.startsWith('은빛 상자'))
                      ? 'assets/images/chest_partySilver.webp'
                      : got.any((g) => g.startsWith('동빛 상자'))
                          ? 'assets/images/chest_partyBronze.webp'
                          : got.any((g) => g.startsWith('파티 상자'))
                              ? 'assets/images/chest_party.webp'
                              : 'assets/images/item_footTicket.webp',
              height: 72,
              errorBuilder: (_, __, ___) => const SizedBox()),
          const SizedBox(height: 6),
          for (final g in got)
            Text(g, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요'))],
      ),
    );
  }

  Future<void> _fight() async {
    final b = c.startPartyBoss();
    if (b == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PartyBossScreen(controller: c, battle: b)));
  }

  Future<void> _kick(PartyMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('${m.name}님을 내보낼까요?'),
        content: const Text('내보내면 다시 초대 코드로 들어와야 해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(
              key: const Key('partyKickYes'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('내보내기')),
        ],
      ),
    );
    if (ok == true) await _run(() => c.kickMember(m.uid), ok: '${m.name}님을 내보냈어요');
  }

  Future<void> _leave(PartyView v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('파티를 나갈까요?'),
        content: KText(v.owner && v.members.length > 1
            ? '파티장을 다음 사람에게 넘기고 나가요. 이번 주에 보탠 걸음 · 피해는 파티에 남아요.'
            : '이번 주에 보탠 걸음 · 피해는 파티에 남아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(
              key: const Key('partyLeaveYes'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true) await _run(c.leaveParty, ok: '파티를 나왔어요');
  }

  Future<void> _style(PartyView v) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => PartyStyleSheet(controller: c, view: v),
      );
}

/// 꾸미기 (파티장): 이름 · 깃발 문양 8 · 색 8. 없는 문양 · 색은 발자국 표로
class PartyStyleSheet extends StatefulWidget {
  const PartyStyleSheet({super.key, required this.controller, required this.view});

  final AppController controller;
  final PartyView view;

  @override
  State<PartyStyleSheet> createState() => _PartyStyleSheetState();
}

class _PartyStyleSheetState extends State<PartyStyleSheet> {
  AppController get c => widget.controller;
  late final _name = TextEditingController(text: widget.view.name);
  late int _emblem = widget.view.emblem;
  late int _color = widget.view.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _buy(Future<String?> Function() f) async {
    final e = await f();
    if (!mounted) return;
    if (e != null) showTopNotice(context, e, icon: Icons.info_outline_rounded);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('partyStyleSheet'),
          padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PartyFlag(emblem: _emblem, color: _color, size: 56),
                const SizedBox(width: 10),
                Expanded(child: Text('파티 꾸미기', style: AppText.title(18))),
                _Tickets(n: c.partyLocal.tickets),
              ]),
              const SizedBox(height: 10),
              TextField(
                key: const Key('partyStyleName'),
                controller: _name,
                maxLength: 12,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: '파티 이름', counterText: ''),
              ),
              const SizedBox(height: 10),
              Text('깃발 문양', style: AppText.title(14, color: AppColors.goldBright)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < PartyRules.emblems.length; i++)
                  _pick(
                    key: 'styleEmblem_$i',
                    selected: _emblem == i,
                    owned: c.hasEmblem(i),
                    price: PartyRules.emblemPrice,
                    onTap: () => c.hasEmblem(i)
                        ? setState(() => _emblem = i)
                        : _buy(() => c.buyEmblem(i)),
                    child: EmblemIcon(index: i, size: 30),
                  ),
              ]),
              const SizedBox(height: 10),
              Text('깃발 색', style: AppText.title(14, color: AppColors.goldBright)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < PartyRules.colors.length; i++)
                  _pick(
                    key: 'styleColor_$i',
                    selected: _color == i,
                    owned: c.hasColor(i),
                    price: PartyRules.colorPrice,
                    onTap: () =>
                        c.hasColor(i) ? setState(() => _color = i) : _buy(() => c.buyColor(i)),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                          color: Color(PartyRules.colors[i]), shape: BoxShape.circle),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              GoldButton(
                key: const Key('partyStyleSave'),
                label: '저장',
                height: 46,
                fontSize: 18,
                onPressed: c.partyBusy
                    ? null
                    : () async {
                        final name = _name.text.trim();
                        final ok = await c.styleParty(
                          name: name == widget.view.name ? null : name,
                          emblem: _emblem,
                          color: _color,
                        );
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context).pop();
                        } else {
                          showTopNotice(context, PartyRules.errorText(c.partyError ?? ''),
                              icon: Icons.info_outline_rounded);
                        }
                      },
              ),
            ]),
          ),
        ),
      );

  Widget _pick({
    required String key,
    required bool selected,
    required bool owned,
    required int price,
    required VoidCallback onTap,
    required Widget child,
  }) =>
      GestureDetector(
        key: Key(key),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35),
                width: selected ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Opacity(opacity: owned ? 1 : 0.35, child: child),
            if (!owned)
              Text('표 $price', style: const TextStyle(color: AppColors.goldBright, fontSize: 10)),
          ]),
        ),
      );
}

class _Tickets extends StatelessWidget {
  const _Tickets({required this.n});

  final int n;

  @override
  Widget build(BuildContext context) => Row(key: const Key('partyFootTickets'), children: [
        Image.asset('assets/images/item_footTicket.webp',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.confirmation_num_rounded, color: AppColors.gold, size: 20)),
        const SizedBox(width: 3),
        Text('$n', style: AppText.title(16, color: AppColors.goldBright)),
      ]);
}

/// 파티 상점 (발자국 표): 금화 · 마석 · 재료 꾸러미 · 모집권(주 2장). 깃발은 꾸미기에서
Future<void> showPartyShop(BuildContext context, AppController c) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Padding(
            key: const Key('partyShop'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('파티 상점', style: AppText.title(18))),
                _Tickets(n: c.partyLocal.tickets),
              ]),
              const SizedBox(height: 4),
              const Text('함께 걷기 · 파티 보스에서 받은 발자국 표로 사요. 깃발 문양 · 색은 「꾸미기」에서.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              for (final it in PartyRules.shop)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(
                      width: 36,
                      child: switch (it.id) {
                        'bundle' => const MaterialIcon(MaterialId.hardWood, size: 30),
                        'recruit' => const Icon(Icons.badge_rounded, color: AppColors.goldBright),
                        'mana' => Image.asset('assets/images/icon_mana_stone.webp',
                            width: 30, errorBuilder: (_, __, ___) => const Icon(Icons.diamond_rounded, color: AppColors.gold)),
                        _ => Image.asset('assets/images/icon_gold.webp',
                            width: 30, errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on_rounded, color: AppColors.gold)),
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.name,
                            style: const TextStyle(color: AppColors.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                        if (it.weekLimit > 0)
                          Text('이번 주 ${c.partyBought(it.id)} / ${it.weekLimit}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ]),
                    ),
                    FilledButton(
                      key: Key('partyBuy_${it.id}'),
                      onPressed: c.partyLocal.tickets >= it.price &&
                              (it.weekLimit == 0 || c.partyBought(it.id) < it.weekLimit)
                          ? () async {
                              final e = await c.buyPartyItem(it);
                              if (context.mounted) {
                                showTopNotice(context, e ?? '${it.name}을(를) 샀어요',
                                    icon: e == null ? Icons.check_circle_rounded : Icons.info_outline_rounded);
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                      child: Text('표 ${it.price}', style: const TextStyle(color: AppColors.goldInk)),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
