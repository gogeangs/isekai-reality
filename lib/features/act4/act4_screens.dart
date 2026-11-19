import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../chat/chat_screens.dart';
import '../profile/profile_screen.dart' show SocialFace;
import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../act3/act3_town.dart' show speakerOf;
import '../awakening/awakening_screen.dart' show IllustratedScene;
import '../battle/battle_view.dart';
import '../battle/hero_rig.dart' show weaponKindOf;
import '../party/party_flag.dart';
import '../settings/account_section.dart' show LoginButton, signInFlow;
import '../smithy/equipment_view.dart' show EquipIcon;
import '../town/material_view.dart';
import '../act5/erbard_screens.dart' show openErbard;

/// 4막 장면을 차례로 본다 (볼 장면이 없을 때까지)
Future<void> showAct4Pending(BuildContext context, AppController c) async {
  var guard = 0;
  while (context.mounted && guard++ < 8) {
    final s4 = c.pendingAct4Scene;
    final s = s4 ?? c.pendingAct5Scene;
    if (s == null) return;
    final act = s4 != null ? 4 : 5;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => Act4SceneScreen(controller: c, scene: s, act: act)));
    if (!(act == 4 ? c.act4.has(s.id) : c.act5.has(s.id))) return;
  }
}

/// 4막 「길드 창설」 장면 한 개 (묶음 59 #246)
class Act4SceneScreen extends StatefulWidget {
  const Act4SceneScreen({super.key, required this.controller, required this.scene, this.act = 4});

  final AppController controller;
  final Act4Scene scene;

  /// 묶음 60: 5막 장면도 같은 화면 (본 기록은 5막 쪽에)
  final int act;

  @override
  State<Act4SceneScreen> createState() => _Act4SceneScreenState();
}

class _Act4SceneScreenState extends State<Act4SceneScreen> {
  AppController get c => widget.controller;
  int _i = 0;
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
    if (_i < widget.scene.lines.length - 1) {
      setState(() => _i++);
      return;
    }
    if (_done) return;
    _done = true;
    final s = widget.scene;
    if (widget.act == 5) {
      await c.markAct5Scene(s);
      if (!mounted) return;
      if (s.id == 'e1c') showTopNotice(context, '에르바르드 대륙 지도가 열렸어요 · 2,000보마다 공성권을 모아요', icon: Icons.map_rounded);
      if (s.id == 'e2a') {
        showTopNotice(
            context,
            c.erbardGuild && c.erbard.myEstates.isNotEmpty
                ? '수비대 배치가 열렸어요 · 우리 길드 깃발이 에르바르드에 꽂혔어요'
                : '수비대 배치가 열렸어요',
            icon: Icons.flag_rounded);
      }
      if (s.id == 'e2b') showTopNotice(context, '개척 보상 · 등불 인장 ${ErbardRules.pioneerSeals} · 금화 ${ErbardRules.pioneerGold}', icon: Icons.explore_rounded);
      if (s.id == 'e3b') showTopNotice(context, '칭호 「에르바르드의 개척자」 · ${ErbardRules.erbardTeaser}', icon: Icons.flag_rounded);
      Navigator.of(context).pop();
      return;
    }
    await c.markAct4Scene(s);
    if (!mounted) return;
    if (s.giveCharter) {
      showTopNotice(context, '리안에게 「길드 창설 증서」를 받았어요', icon: Icons.description_rounded);
    }
    if (c.act4Done && s.id == 'c5c') {
      showTopNotice(context, '칭호 「등불의 맹세」 · ${GuildRules.act5Teaser}', icon: Icons.flag_rounded);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scene;
    final (who, line) = s.lines[_i];
    final sp = speakerOf(c, who);
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: Key('act${widget.act}Scene_${s.id}'),
        backgroundColor: AppColors.deepNight,
        body: Stack(children: [
          Positioned.fill(
            child: IllustratedScene(
              key: ValueKey('act${widget.act}${s.id}$_i'),
              image: s.image,
              speaker: sp.name,
              tailX: 0.5,
              line: line,
              lineKey: 'act${widget.act}-${s.id}-$_i',
              onNext: _next,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xAA000000), borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.act}막 · ${s.place}',
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 마을 「길드 회관」 (묶음 59 #246): 4막 이야기 · 길드 만들기/들어가기 · 길드 · 회관 · 레이드 · 상점
class GuildHallScreen extends StatefulWidget {
  const GuildHallScreen({super.key, required this.controller, this.tab = 0, this.inviteCode});

  final AppController controller;
  final int tab;

  /// 묶음 60: 길드 초대 링크로 왔으면 코드 칸에 미리
  final String? inviteCode;

  @override
  State<GuildHallScreen> createState() => _GuildHallScreenState();
}

class _GuildHallScreenState extends State<GuildHallScreen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;
  final _name = TextEditingController();
  late final _code = TextEditingController(text: widget.inviteCode ?? '');
  final _line = TextEditingController();
  int _emblem = 0, _color = 0;
  bool _open = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await c.refreshGuild();
      // 묶음 61: 금고 나눠 주기 · 기부 금화(거래 지갑)를 알려고
      if (c.act5Open) await c.refreshErbard();
      if (c.guild?.inGuild == true && !(c.guild?.lian ?? true) && c.marketWallet == null) await c.refreshWallet();
      if (mounted) await showAct4Pending(context, c);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _line.dispose();
    super.dispose();
  }

  void _say(String text, {bool ok = true}) {
    if (!mounted) return;
    showTopNotice(context, text, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);
  }

  void _err() => _say(GuildRules.errorText(c.guildError ?? ''), ok: false);

  Future<void> _run(Future<bool> Function() f, {String? ok}) async {
    final done = await f();
    if (!mounted) return;
    if (done) {
      if (ok != null) _say(ok);
    } else {
      _err();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('guildHall'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final g = c.guild;
            final inGuild = g?.inGuild ?? false;
            return Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 0),
                child: OrnateTopBar(
                  title: '길드 회관',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: _seals(),
                ),
              ),
              if (inGuild)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Row(children: [
                    for (final (i, t) in const ['길드', '회관', '레이드', '상점'].indexed)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _TabChip(
                            key: Key('guildTab_$i'),
                            label: t,
                            on: _tab == i,
                            dot: i == 2 && _raidNews(g!),
                            onTap: () => setState(() => _tab = i),
                          ),
                        ),
                      ),
                    // 묶음 68 #275: 길드 대화방 (로그인 · 서버 길드)
                    if (!g!.lian && g.id != null && c.chatOpen)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _TabChip(
                            key: const Key('guildTab_chat'),
                            label: '대화',
                            on: false,
                            dot: (c.chatMe?.room('g_${g.id}')?.unread ?? 0) > 0,
                            onTap: () => openRoom(context, c, 'g_${g.id}', name: '길드 · ${g.name}'),
                          ),
                        ),
                      ),
                  ]),
                ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, pad.bottom + 24),
                  children: [
                    _story(),
                    const SizedBox(height: 10),
                    if (!inGuild)
                      ..._noGuild()
                    else
                      switch (_tab) {
                        1 => _hall(g!),
                        2 => _raids(g!),
                        3 => _shop(g!),
                        _ => _guildTab(g!),
                      },
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  bool _raidNews(GuildView g) {
    bool news(GuildRaidView? r) => r != null && ((r.defeated && !r.claimed && r.myDamage > 0) || (!r.defeated && r.tickets > 0));
    return news(g.raid) || (c.act4.has('c4a') && news(g.giant));
  }

  Widget _seals() => Row(key: const Key('guildSeals'), mainAxisSize: MainAxisSize.min, children: [
        Image.asset(GuildRules.sealImage,
            width: 24, errorBuilder: (_, __, ___) => const Icon(Icons.local_fire_department_rounded, color: AppColors.goldBright)),
        const SizedBox(width: 4),
        Text(comma(c.lanternSeals),
            style: const TextStyle(color: AppColors.goldBright, fontSize: 15, fontWeight: FontWeight.w900)),
      ]);

  // ───────────── 4막 이야기 카드

  Widget _story() {
    final ch = GuildRules.chapter(c.act4Chapter);
    final pending = c.pendingAct4Scene;
    return OrnatePanel(
      key: const Key('act4Story'),
      ornament: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.flag_rounded, color: AppColors.goldBright, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(c.act4Done ? '4막 「길드 창설」 · 끝' : '4막 ${ch.n}장 · ${ch.title}',
                style: AppText.title(16)),
          ),
        ]),
        const SizedBox(height: 4),
        KText(c.act4Goal,
            key: const Key('act4Goal'),
            style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.4)),
        if (!c.act4Done && ch.n > 1) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: c.act4Progress,
              minHeight: 8,
              backgroundColor: const Color(0x33FFFFFF),
              color: AppColors.goldBright,
            ),
          ),
        ],
        if (c.act5Open) ...[
          const SizedBox(height: 10),
          GoldButton(
            key: const Key('openErbard'),
            label: c.act5.has('e1b') ? '에르바르드 대륙으로' : '5막 「흑등 연맹의 귀환」',
            height: 44,
            fontSize: 17,
            onPressed: () => openErbard(context, c),
          ),
        ],
        if (pending != null) ...[
          const SizedBox(height: 10),
          GoldButton(
            key: const Key('act4Watch'),
            label: '이야기 보기',
            height: 44,
            fontSize: 17,
            onPressed: () => showAct4Pending(context, c),
          ),
        ],
      ]),
    );
  }

  // ───────────── 길드가 없을 때

  List<Widget> _noGuild() {
    final a = c.act4;
    if (a.chapter < 2 || !a.has('c2c')) {
      return [
        const OrnatePanel(
          child: KText('마을 사람들의 이야기를 따라가면 길드를 만들 수 있어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13.5)),
        ),
      ];
    }
    return [
      if (!c.guildReady)
        OrnatePanel(
          key: const Key('guildLogin'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KText('길드를 만들거나 다른 각성자의 길드에 들어가려면 로그인해 주세요. 리안의 길드는 로그인 없이도 함께해요.',
                style: TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 10),
            if (c.cloudAvailable)
              for (final p in c.loginProviders) ...[
                LoginButton(provider: p, busy: c.cloudBusy, onPressed: () => signInFlow(context, c, p)),
                const SizedBox(height: 8),
              ],
          ]),
        )
      else ...[
        _createPanel(),
        const SizedBox(height: 10),
        _joinPanel(),
      ],
      const SizedBox(height: 10),
      OrnatePanel(
        key: const Key('lianGuildPanel'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            ClipOval(
                child: Image.asset('assets/images/npc_lian.webp',
                    width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 40))),
            const SizedBox(width: 10),
            Expanded(child: Text(GuildRules.lianGuildName, style: AppText.title(16))),
          ]),
          const SizedBox(height: 6),
          const KText('혼자여도 괜찮아요. 리안과 동료들이 함께 걷고, 레이드도 함께 싸워요. 언제든 다른 길드로 옮길 수 있어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 8),
          FrameButton(
            key: const Key('joinLian'),
            label: '리안의 길드에 들어가기',
            height: 44,
            onPressed: c.canJoinLian
                ? () async {
                    await c.joinLianGuild();
                    _say('리안의 길드에 들어갔어요');
                  }
                : null,
          ),
        ]),
      ),
    ];
  }

  Widget _createPanel() => OrnatePanel(
        key: const Key('guildCreatePanel'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('길드 만들기', style: AppText.title(16)),
          const SizedBox(height: 4),
          Row(children: [
            Image.asset(GuildRules.charterImage,
                width: 26, errorBuilder: (_, __, ___) => const Icon(Icons.description_rounded, color: AppColors.gold)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  c.hasCharter ? '길드 창설 증서 · 금화 ${comma(GuildRules.createGold)}' : '길드 창설 증서가 있어야 해요',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          ]),
          const SizedBox(height: 6),
          TextField(
            key: const Key('guildNameField'),
            controller: _name,
            maxLength: 12,
            style: const TextStyle(color: AppColors.text),
            decoration: InputDecoration(
              hintText: '${c.profile.name}의 길드',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              counterText: '',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          _flagPick(maxEmblem: 4),
          const SizedBox(height: 6),
          Row(children: [
            const Text('들어오는 방법', style: TextStyle(color: AppColors.text, fontSize: 13)),
            const Spacer(),
            ChoiceChip(
              key: const Key('guildOpenPublic'),
              label: const Text('공개'),
              selected: _open,
              onSelected: (_) => setState(() => _open = true),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              key: const Key('guildOpenInvite'),
              label: const Text('초대만'),
              selected: !_open,
              onSelected: (_) => setState(() => _open = false),
            ),
          ]),
          const SizedBox(height: 8),
          if (c.hasCharter)
            GoldButton(
              key: const Key('guildCreate'),
              label: '길드 만들기',
              height: 46,
              fontSize: 18,
              onPressed: c.guildBusy || !c.canCreateGuild
                  ? null
                  : () {
                      final n = _name.text.trim().isEmpty ? '${c.profile.name}의 길드' : _name.text.trim();
                      _run(() => c.createGuild(n, emblem: _emblem, color: _color, open: _open),
                          ok: '길드를 만들었어요! 초대 코드를 보내 보세요');
                    },
            )
          else
            FrameButton(
              key: const Key('askCharter'),
              label: '리안에게 증서 다시 받기',
              height: 44,
              onPressed: c.canAskCharter
                  ? () async {
                      await c.askCharter();
                      _say('길드 창설 증서를 받았어요');
                    }
                  : null,
            ),
        ]),
      );

  Widget _flagPick({required int maxEmblem}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PartyFlag(emblem: _emblem, color: _color, size: 52),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < maxEmblem.clamp(1, PartyRules.emblems.length); i++)
                _Pick(
                  key: Key('guildEmblem_$i'),
                  on: _emblem == i,
                  onTap: () => setState(() => _emblem = i),
                  child: EmblemIcon(index: i, size: 24),
                ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < PartyRules.colors.length; i++)
                _Pick(
                  key: Key('guildColor_$i'),
                  on: _color == i,
                  onTap: () => setState(() => _color = i),
                  child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: Color(PartyRules.colors[i]), shape: BoxShape.circle)),
                ),
            ]),
          ]),
        ),
      ]);

  Widget _joinPanel() => OrnatePanel(
        key: const Key('guildJoinPanel'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('길드 들어가기', style: AppText.title(16)),
          const SizedBox(height: 6),
          FrameButton(
            key: const Key('guildBrowse'),
            label: '공개 길드 둘러보기',
            height: 44,
            onPressed: c.guildBusy ? null : _browse,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('guildCodeField'),
                controller: _code,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: AppColors.text, letterSpacing: 4, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: '초대 코드 여섯 글자',
                  hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 0, fontSize: 14),
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('guildJoinCode'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: c.guildBusy
                  ? null
                  : () {
                      if (_code.text.trim().length < 6) return;
                      _run(() => c.joinGuild(code: _code.text.trim().toUpperCase()), ok: '길드에 들어갔어요!');
                    },
              child: const Text('들어가기', style: TextStyle(color: AppColors.goldInk)),
            ),
          ]),
        ]),
      );

  Future<void> _browse() async {
    final list = await c.listGuilds();
    if (!mounted) return;
    if (list == null) return _err();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => _GuildListSheet(controller: c, first: list, onJoined: () => _say('길드에 들어갔어요!')),
    );
  }

  // ───────────── 길드 탭

  Widget _guildTab(GuildView g) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(g),
        const SizedBox(height: 10),
        _walk(g),
        const SizedBox(height: 10),
        _levels(g),
        const SizedBox(height: 8),
        if (!g.lian && g.role == 'owner')
          FrameButton(key: const Key('guildStyleOpen'), label: '깃발 · 이름 꾸미기', height: 44, onPressed: () => _style(g)),
        TextButton(
          key: const Key('guildLeave'),
          onPressed: () => _leave(g),
          child: const Text('길드 나가기', style: TextStyle(color: AppColors.textMuted)),
        ),
      ]);

  Widget _header(GuildView g) => OrnatePanel(
        key: const Key('guildHeader'),
        ornament: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            PartyFlag(emblem: g.emblem, color: g.color, size: 60, gold: g.goldFlag),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, key: const Key('guildName'), style: AppText.title(19)),
                Text('길드 Lv.${g.level} · ${g.members.length}${g.lian ? '' : ' / ${g.size}'}명',
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w800)),
                if (!g.lian && g.level < 10) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: const Key('guildLevelBar'),
                      value: g.progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0x33FFFFFF),
                      color: AppColors.gold,
                    ),
                  ),
                ],
                if (!g.lian && g.code.isNotEmpty)
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    const Text('초대 코드 ', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    Text(g.code,
                        key: const Key('guildCode'),
                        style: const TextStyle(
                            color: AppColors.goldBright, fontSize: 15, letterSpacing: 2, fontWeight: FontWeight.w900)),
                    InkWell(
                      key: const Key('guildCopy'),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: g.code));
                        _say('초대 코드를 복사했어요');
                      },
                      child: const Padding(
                          padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted)),
                    ),
                    InkWell(
                      key: const Key('guildShare'),
                      onTap: () => SharePlus.instance.share(ShareParams(text: PartyRules.guildInviteText(g.name, g.code))),
                      child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.ios_share_rounded, size: 16, color: AppColors.textMuted)),
                    ),
                  ]),
              ]),
            ),
          ]),
          if (!g.lian && c.erbard.server && c.erbard.treasury > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('길드 금고 · 금화 ${comma(c.erbard.treasury)} (영지 거래소 몫)',
                  key: const Key('guildTreasury'), style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
            ),
          if (g.titles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final t in g.titles)
                ChipBadge(text: GuildRules.boss(t) == null ? t : TitleRules.info(GuildRules.boss(t)!.title).name),
            ]),
          ],
          const SizedBox(height: 8),
          for (final (i, m) in ([...g.members]..sort((a, b) => b.weekSteps.compareTo(a.weekSteps))).indexed)
            _member(g, m, i + 1),
        ]),
      );

  Widget _member(GuildView g, GuildMember m, int rank) => InkWell(
        key: Key('guildMember_${m.uid}'),
        onTap: m.me || g.lian
            ? null
            : g.staff
                ? () => _manage(g, m)
                : c.friendsOpen
                    ? () => askFriend(context, c, m.uid, m.name)
                    : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 22,
                child: Text('$rank', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
            SizedBox(
              width: 18,
              child: switch (m.role) {
                'owner' => const Icon(Icons.workspace_premium_rounded, size: 16, color: AppColors.goldBright),
                'vice' => const Icon(Icons.shield_rounded, size: 15, color: AppColors.gold),
                _ => null,
              },
            ),
            const SizedBox(width: 4),
            // 묶음 75 #335: 프로필 사진
            SocialFace(key: Key('guildFace_${m.uid}'), face: m.me ? c.avatarFace : m.face),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${m.name}${m.me ? ' (나)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: m.me ? AppColors.goldBright : AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            Text('Lv.${m.level}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            const SizedBox(width: 10),
            SizedBox(
              width: 74,
              child: Text('${comma(m.weekSteps)}보',
                  textAlign: TextAlign.right, style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
            ),
          ]),
        ),
      );

  Widget _walk(GuildView g) => OrnatePanel(
        key: const Key('guildWalk'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.directions_walk_rounded, color: AppColors.goldBright, size: 20),
            const SizedBox(width: 6),
            Text('이번 주 길드 걸음', style: AppText.title(16)),
          ]),
          Text(g.lian ? '리안의 길드는 내 걸음으로 채워요 · 월요일에 새로' : '길드원 모두의 걸음을 합쳐요 · 월요일에 새로',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(width: 44, child: Text('${i + 1}단계', style: const TextStyle(color: AppColors.text, fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: i < g.walkProgress.length ? g.walkProgress[i] : 0,
                      minHeight: 8,
                      backgroundColor: const Color(0x33FFFFFF),
                      color: AppColors.goldBright,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: g.walkClaimed.contains(i)
                      ? const Text('받았어요', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12))
                      : FilledButton(
                          key: Key('guildWalkClaim_$i'),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(0, 32)),
                          onPressed: i < g.walkDone.length && g.walkDone[i] && !c.guildBusy
                              ? () => _claim('walk', tier: i)
                              : null,
                          child: Text('인장 ${GuildRules.weekSeals[i]}',
                              style: const TextStyle(color: AppColors.goldInk, fontSize: 12.5)),
                        ),
                ),
              ]),
            ),
        ]),
      );

  Future<void> _claim(String kind, {int? tier}) async {
    final got = await c.claimGuild(kind, tier: tier);
    if (!mounted) return;
    if (got == null) return _err();
    _say(got.isEmpty ? '받았어요' : got.join(' · '));
  }

  Widget _levels(GuildView g) => OrnatePanel(
        key: const Key('guildLevels'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(g.lian ? '리안의 길드' : '길드 레벨마다 열리는 것', style: AppText.title(15)),
          const SizedBox(height: 4),
          if (g.lian)
            const KText('리안의 길드엔 레벨이 없어요. 회관 ★1 · 레이드 · 상점을 쓸 수 있어요. 회관을 키우고 꾸미려면 내 길드가 있어야 해요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4))
          else
            for (final e in GuildRules.levelUnlocks.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 48,
                    child: Text('Lv.${e.key}',
                        style: TextStyle(
                            color: g.level >= e.key ? AppColors.goldBright : AppColors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: Text(e.value,
                        style: TextStyle(color: g.level >= e.key ? AppColors.text : AppColors.textMuted, fontSize: 12.5)),
                  ),
                ]),
              ),
        ]),
      );

  Future<void> _manage(GuildView g, GuildMember m) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SafeArea(
          child: Padding(
            key: const Key('guildManage'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(m.name, style: AppText.title(18)),
              const SizedBox(height: 10),
              if (c.friendsOpen && !(c.chatMe?.friends.any((f) => f.uid == m.uid) ?? false)) ...[
                FrameButton(
                    key: const Key('guildMemberFriend'),
                    label: '친구 신청',
                    height: 42,
                    onPressed: () {
                      Navigator.pop(sheet);
                      sendFriendAsk(context, c, m.uid, m.name);
                    }),
                const SizedBox(height: 8),
              ],
              if (g.role == 'owner') ...[
                if (m.role != 'vice')
                  FrameButton(
                      key: const Key('guildMakeVice'),
                      label: '부길드장으로',
                      height: 42,
                      onPressed: () {
                        Navigator.pop(sheet);
                        _run(() => c.setGuildRole(m.uid, 'vice'), ok: '${m.name}님이 부길드장이 됐어요');
                      })
                else
                  FrameButton(
                      key: const Key('guildMakeMember'),
                      label: '길드원으로',
                      height: 42,
                      onPressed: () {
                        Navigator.pop(sheet);
                        _run(() => c.setGuildRole(m.uid, 'member'));
                      }),
                const SizedBox(height: 8),
                FrameButton(
                    key: const Key('guildMakeOwner'),
                    label: '길드장 넘기기',
                    height: 42,
                    onPressed: () async {
                      Navigator.pop(sheet);
                      if (await _confirm('${m.name}님에게 길드장을 넘길까요?')) {
                        await _run(() => c.setGuildRole(m.uid, 'owner'), ok: '길드장을 넘겼어요');
                      }
                    }),
                const SizedBox(height: 8),
              ],
              if (m.role != 'owner' && (g.role == 'owner' || m.role == 'member'))
                TextButton(
                    key: const Key('guildKick'),
                    onPressed: () async {
                      Navigator.pop(sheet);
                      if (await _confirm('${m.name}님을 길드에서 내보낼까요?')) {
                        await _run(() => c.kickGuildMember(m.uid), ok: '내보냈어요');
                      }
                    },
                    child: const Text('내보내기', style: TextStyle(color: AppColors.textMuted))),
            ]),
          ),
        ),
      );

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          content: Text(text, style: const TextStyle(color: AppColors.text)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('취소')),
            TextButton(key: const Key('confirmYes'), onPressed: () => Navigator.pop(d, true), child: const Text('네')),
          ],
        ),
      ) ??
      false;

  Future<void> _leave(GuildView g) async {
    final msg = g.lian
        ? '리안의 길드에서 나올까요? 언제든 다시 들어올 수 있어요.'
        : g.role == 'owner'
            ? '길드를 나갈까요? 길드장은 부길드장(없으면 가장 오래된 길드원)에게 넘어가요.'
            : '길드를 나갈까요?';
    if (!await _confirm(msg)) return;
    await _run(() => c.leaveGuild(), ok: '길드를 나왔어요');
  }

  Future<void> _style(GuildView g) async {
    _name.text = g.name;
    _emblem = g.emblem;
    _color = g.color;
    _open = g.open;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => StatefulBuilder(
        builder: (context, set) => SafeArea(
          child: Padding(
            key: const Key('guildStyle'),
            padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('깃발 · 이름', style: AppText.title(18)),
              TextField(
                key: const Key('guildStyleName'),
                controller: _name,
                maxLength: 12,
                style: const TextStyle(color: AppColors.text),
                decoration: const InputDecoration(labelText: '길드 이름', counterText: ''),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(builder: (_, __) => _flagPick(maxEmblem: g.level >= 9 ? PartyRules.emblems.length : 4)),
              if (g.level < 9)
                const Text('길드 Lv.9에 깃발 문양 · 색이 늘어나요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('공개 길드 목록에 보이기', style: TextStyle(color: AppColors.text, fontSize: 14)),
                value: _open,
                onChanged: (v) => set(() => _open = v),
              ),
              GoldButton(
                key: const Key('guildStyleSave'),
                label: '저장',
                height: 46,
                fontSize: 18,
                onPressed: () async {
                  final n = _name.text.trim();
                  final ok = await c.styleGuild(
                      name: n == g.name ? null : n, emblem: _emblem, color: _color, open: _open);
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                  } else {
                    _err();
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // ───────────── 회관 탭

  Widget _hall(GuildView g) {
    final star = g.lian ? 1 : g.star;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OrnatePanel(
        key: const Key('guildHallView'),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 2,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(children: [
                  Positioned.fill(
                      child: Image.asset(GuildRules.sceneHall,
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.night))),
                  Positioned(
                    left: w / 2 - h * 0.45,
                    top: h * 0.02,
                    width: h * 0.9,
                    height: h * 0.9,
                    child: Image.asset(GuildRules.hallImage(star),
                        key: Key('guildHallStar_$star'), errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                  for (var i = 0; i < GuildRules.decoSpots.length; i++)
                    Positioned(
                      left: GuildRules.decoSpots[i].$1 * w - h * 0.14,
                      top: GuildRules.decoSpots[i].$2 * h - h * 0.24,
                      width: h * 0.28,
                      height: h * 0.28,
                      child: GestureDetector(
                        key: Key('guildDecoSlot_$i'),
                        onTap: g.staff && !g.lian ? () => _decoSlot(g, i) : null,
                        child: switch (i < g.slots.length ? g.slots[i] : null) {
                          final String id => GuildDecoImage(id),
                          null => g.staff && !g.lian
                              ? DecoratedBox(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0x88FFE7A0), width: 1.5)),
                                  child: const Icon(Icons.add_rounded, color: Color(0xAAFFE7A0)))
                              : const SizedBox(),
                        },
                      ),
                    ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('회관 ', style: AppText.title(15)),
            StarRow(star: star),
            const Spacer(),
            if (g.staff && !g.lian)
              const Text('빈 자리를 눌러 꾸며요', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
          for (final e in GuildRules.stars.entries)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${'★' * e.key}  ${e.value}',
                  style: TextStyle(color: star >= e.key ? AppColors.text : AppColors.textMuted, fontSize: 12.5)),
            ),
          if (!g.lian && star < 4) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                key: const Key('guildStarBar'),
                value: g.starProgress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0x33FFFFFF),
                color: AppColors.goldBright,
              ),
            ),
            if (g.nextStarLevel != null && g.level < g.nextStarLevel!)
              Text('★${star + 1}은 길드 Lv.${g.nextStarLevel}부터 올릴 수 있어요',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      if (!g.lian) _donate(),
      if (!g.lian) const SizedBox(height: 10),
      if (!g.lian) ...[_treasury(g), const SizedBox(height: 10)],
      _board(g),
      if (!g.lian && star >= 2) ...[const SizedBox(height: 10), _storage(g)],
    ]);
  }

  Future<void> _decoSlot(GuildView g, int slot) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SafeArea(
          child: Padding(
            key: const Key('guildDecoSheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('꾸미기 놓기', style: AppText.title(18)),
              const SizedBox(height: 4),
              if (g.decos.isEmpty)
                const Text('길드 상점에서 꾸미기를 들여 보세요.', style: TextStyle(color: AppColors.textMuted))
              else
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final d in g.decos)
                    InkWell(
                      key: Key('guildDecoPick_$d'),
                      onTap: () {
                        Navigator.pop(sheet);
                        _run(() => c.placeDeco(slot, d));
                      },
                      child: Column(children: [
                        GuildDecoImage(d, size: 58),
                        Text(GuildRules.decoNames[d] ?? d, style: const TextStyle(color: AppColors.text, fontSize: 11.5)),
                      ]),
                    ),
                ]),
              if (slot < g.slots.length && g.slots[slot] != null)
                TextButton(
                    key: const Key('guildDecoClear'),
                    onPressed: () {
                      Navigator.pop(sheet);
                      _run(() => c.placeDeco(slot, null));
                    },
                    child: const Text('이 자리 비우기')),
            ]),
          ),
        ),
      );

  Widget _donate() => OrnatePanel(
        key: const Key('guildDonate'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('회관에 기부하기', style: AppText.title(15)),
          const Text('금화 · 재료를 모으면 회관이 커지고 등불 인장을 받아요 · 하루 한도가 있어요',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text('기부 금화는 거래 지갑에서 · 지갑 금화 ${c.marketWallet == null ? '-' : comma(c.marketWallet!)}',
              key: const Key('guildDonateWallet'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FrameButton(
                key: const Key('guildDonateGold'),
                label: '지갑 금화 ${GuildRules.donateGoldStep}',
                height: 42,
                onPressed: c.guildBusy || (c.marketWallet != null && c.marketWallet! < GuildRules.donateGoldStep)
                    ? null
                    : () async {
                        final s = await c.donateGuild(gold: GuildRules.donateGoldStep);
                        if (!mounted) return;
                        s == null ? _err() : _say(s > 0 ? '기부했어요 · 등불 인장 $s' : '기부했어요');
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FrameButton(
                key: const Key('guildDonateMat'),
                label: '재료',
                height: 42,
                onPressed: c.guildBusy ? null : () => _pickMat('기부할 재료', (m) => c.donateGuild(mats: {m: 1}).then((s) {
                      if (!mounted) return;
                      s == null ? _err() : _say(s > 0 ? '기부했어요 · 등불 인장 $s' : '기부했어요');
                    })),
              ),
            ),
          ]),
        ]),
      );

  Future<void> _pickMat(String title, Future<void> Function(MaterialId) onPick) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) {
          final owned = [
            for (final e in c.player.materials.entries)
              if (e.value > 0) e,
          ];
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
              child: ListView(key: const Key('guildMatSheet'), padding: const EdgeInsets.fromLTRB(18, 16, 18, 12), children: [
                Text(title, style: AppText.title(18)),
                const Text('하나씩 보내요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 8),
                if (owned.isEmpty) const Text('가진 재료가 없어요', style: TextStyle(color: AppColors.textMuted)),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in owned)
                    InkWell(
                      key: Key('guildMat_${e.key.name}'),
                      onTap: () {
                        Navigator.pop(sheet);
                        onPick(e.key);
                      },
                      child: SizedBox(
                        width: 64,
                        child: Column(children: [
                          MaterialIcon(e.key, size: 40),
                          Text(Materials.info(e.key).name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 11)),
                          Text('${e.value}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                        ]),
                      ),
                    ),
                ]),
              ]),
            ),
          );
        },
      );

  /// 묶음 61: 길드 금고 (영지 거래소 몫) — 회관 공사 · 나눠 주기 · 금고 상점 (수비대 강화는 수비대 화면)
  Widget _treasury(GuildView g) {
    final v = c.erbard;
    return OrnatePanel(
      key: const Key('guildTreasury'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.savings_rounded, color: AppColors.goldBright, size: 20),
          const SizedBox(width: 6),
          Text('길드 금고', style: AppText.title(15)),
          const Spacer(),
          Text('금화 ${comma(g.treasury)}', key: const Key('guildTreasuryGold'), style: AppText.title(15, color: AppColors.goldBright)),
        ]),
        const Text('영지에서 모인 거래소 몫이 쌓여요. 길드장 · 부길드장이 쓰고, 쓸 때마다 게시판에 남아요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        if (g.staff) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FrameButton(
                key: const Key('treasuryHall'),
                label: '회관 공사 · 금화 ${comma(GuildRules.treasuryHallStep)}',
                height: 40,
                onPressed: c.guildBusy || g.treasury < GuildRules.treasuryHallStep
                    ? null
                    : () => _run(() => c.treasuryHall(GuildRules.treasuryHallStep), ok: '금고 금화로 회관을 고쳤어요'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FrameButton(
                key: const Key('treasuryShare'),
                label: '길드원에게 나눠 주기',
                height: 40,
                onPressed: g.role == 'owner' && v.canShare && !c.guildBusy && g.treasury > 1 ? () => _shareSheet(g) : null,
              ),
            ),
          ]),
          Text(
              g.role != 'owner'
                  ? '나눠 주기는 길드장이 해요'
                  : v.canShare
                      ? '제${(v.shareNo ?? 0) + 1}회 공성전에 공성권을 쓴 길드원에게 똑같이 보내요'
                      : '공성전이 끝나면 그 공성전에 나선 길드원에게 한 번 나눠 줄 수 있어요',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          const SizedBox(height: 8),
          Text('금고 상점', style: AppText.title(14)),
          const SizedBox(height: 4),
          for (final e in ErbardRules.treasuryShop.entries) _treasuryItem(g, e.key, e.value),
        ],
      ]),
    );
  }

  Widget _treasuryItem(GuildView g, String id, int price) {
    final owned = id == 'goldFlag' ? g.goldFlag : g.decos.contains(id);
    return Padding(
      key: Key('treasuryItem_$id'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 44,
          height: 44,
          child: id == 'goldFlag'
              ? PartyFlag(emblem: g.emblem, color: g.color, size: 44, gold: true)
              : GuildDecoImage(id, size: 44),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(GuildRules.treasuryShopNames[id] ?? id,
                style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
            Text(GuildRules.treasuryShopLines[id] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
        TextButton(
          key: Key('treasuryBuy_$id'),
          onPressed: owned || c.guildBusy || g.treasury < price
              ? null
              : () => _run(() => c.treasuryShop(id), ok: '${GuildRules.treasuryShopNames[id]}을(를) 들였어요'),
          child: Text(owned ? '있어요' : '금화 ${comma(price)}'),
        ),
      ]),
    );
  }

  Future<void> _shareSheet(GuildView g) async {
    final max = (g.treasury * ErbardRules.shareMaxRate).floor();
    final amount = TextEditingController(text: '$max');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => Padding(
        key: const Key('treasuryShareSheet'),
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.viewInsetsOf(sheet).bottom),
        child: StatefulBuilder(
          builder: (context, set) {
            final a = int.tryParse(amount.text) ?? 0;
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('길드원에게 나눠 주기', style: AppText.title(18)),
              const SizedBox(height: 4),
              KText(
                  '제${(c.erbard.shareNo ?? 0) + 1}회 공성전에 공성권을 쓴 길드원에게 똑같이 나눠 우편으로 보내요. '
                  '금고의 절반(금화 ${comma(max)})까지, 한 사람에 금화 ${comma(ErbardRules.sharePerHeadMax)}까지예요. 공성전마다 한 번이에요.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.45)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('treasuryShareAmount'),
                controller: amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => set(() {}),
                style: const TextStyle(color: AppColors.text, fontSize: 18),
                decoration: const InputDecoration(labelText: '나눌 금화', suffixText: '금화'),
              ),
              const SizedBox(height: 12),
              GoldButton(
                key: const Key('treasuryShareOk'),
                label: '나눠 주기',
                height: 46,
                fontSize: 17,
                onPressed: a <= 0 || a > max
                    ? null
                    : () async {
                        Navigator.pop(sheet);
                        await _run(() => c.treasuryShare(a), ok: '나눠 줬어요 · 게시판에 남았어요');
                      },
              ),
            ]);
          },
        ),
      ),
    );
    amount.dispose();
  }

  Widget _board(GuildView g) => OrnatePanel(
        key: const Key('guildBoard'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('길드 게시판 · 한마디', style: AppText.title(15)),
          const SizedBox(height: 6),
          // 묶음 65: 공성전 소식 (최근 5줄)
          for (final (i, n) in g.news.take(5).indexed)
            Padding(
              key: Key('guildNews_$i'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(TextSpan(children: [
                const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.flag_rounded, size: 14, color: Color(0xFFFF8A65)))),
                TextSpan(text: n.text, style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
              ])),
            ),
          // 묶음 61: 금고 쓰기 기록 (누가 · 무엇에 · 얼마)
          for (final (i, t) in g.treasuryLog.take(5).indexed)
            Padding(
              key: Key('guildTreasuryLog_$i'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(TextSpan(children: [
                const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.savings_rounded, size: 14, color: AppColors.goldBright))),
                TextSpan(
                    text: '${t.name}  ',
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
                TextSpan(
                    text: '금고 금화 ${comma(t.gold)} · ${t.what}',
                    style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
              ])),
            ),
          for (final m in g.members)
            if (m.line.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${m.name}  ',
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  TextSpan(text: m.line, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                ])),
              ),
          if (!g.lian) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('guildLineField'),
                  controller: _line,
                  maxLength: 30,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: const InputDecoration(
                      hintText: '오늘의 한마디', hintStyle: TextStyle(color: AppColors.textMuted), counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('guildLinePost'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                onPressed: c.guildBusy
                    ? null
                    : () async {
                        final t = _line.text.trim();
                        if (t.isEmpty) return;
                        final ok = await c.postGuildLine(t);
                        if (!mounted) return;
                        if (ok) {
                          _line.clear();
                          _say('한마디를 남겼어요');
                        } else {
                          _err();
                        }
                      },
                child: const Text('남기기', style: TextStyle(color: AppColors.goldInk)),
              ),
            ]),
          ],
        ]),
      );

  Widget _storage(GuildView g) => OrnatePanel(
        key: const Key('guildStorage'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('길드 창고', style: AppText.title(15)),
          const Text('길드원에게 재료를 나눠 줘요 · 하루 한도가 있어요',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in g.members)
              if (!m.me)
                ActionChip(
                  key: Key('guildShare_${m.uid}'),
                  label: Text(m.name),
                  onPressed: () => _pickMat('${m.name}님에게 보낼 재료', (mat) async {
                    await _run(() => c.shareToMember(m.uid, mat, 1), ok: '${m.name}님에게 보냈어요');
                  }),
                ),
          ]),
        ]),
      );

  // ───────────── 레이드 탭

  Widget _raids(GuildView g) {
    if (!g.lian && g.level < 4) {
      return const OrnatePanel(
        key: Key('guildRaidLocked'),
        child: KText('길드 Lv.4에 레이드가 열려요. 길드원과 함께 걸어 레벨을 올려요.',
            style: TextStyle(color: AppColors.text, fontSize: 13.5)),
      );
    }
    final showGiant = c.act4.has('c4a') && g.giant != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showGiant) ...[_raidCard(g, g.giant!, giant: true), const SizedBox(height: 10)],
      if (g.raid != null) _raidCard(g, g.raid!, giant: false),
      const SizedBox(height: 8),
      KText(
          g.lian
              ? '리안의 길드에선 리안과 동료들이 함께 싸워 줘요. 걸으면 도전권이 생겨요.'
              : '걸으면 도전권이 생겨요. 길드원 모두의 피해가 합쳐져요. 보스는 월요일마다 바뀌어요.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
    ]);
  }

  Widget _raidCard(GuildView g, GuildRaidView r, {required bool giant}) {
    final b = r.boss ?? GuildRules.giant;
    final weak = c.raidWeakLine(b);
    return OrnatePanel(
      key: Key(giant ? 'guildGiant' : 'guildRaid'),
      ornament: giant,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MonsterPicture(monster: b.monster, size: 84, defeated: r.defeated),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(giant ? '4장 레이드' : '이번 주 레이드',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              Text(Monsters.info(b.monster).name, style: AppText.title(17)),
              const SizedBox(height: 2),
              Text('특별 공격 「${b.special}」', style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
              KText(b.specialText, style: const TextStyle(color: AppColors.text, fontSize: 12, height: 1.35)),
              const SizedBox(height: 2),
              Text('약점 직업 · ${b.weak.map((j) => JobRules.info(j).name).join(' · ')}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (weak != null)
                Text(weak, key: const Key('raidWeak'), style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: (1 - r.progress).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: const Color(0x33FFFFFF),
            color: const Color(0xFFE25D5D),
          ),
        ),
        const SizedBox(height: 6),
        if (r.defeated)
          r.claimed
              ? const Text('보상을 받았어요', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))
              : r.myDamage > 0
                  ? GoldButton(
                      key: Key(giant ? 'giantClaim' : 'raidClaim'),
                      label: '보상 받기',
                      height: 44,
                      fontSize: 17,
                      onPressed: c.guildBusy ? null : () => _claim(giant ? 'giant' : 'raid'),
                    )
                  : const Text('이번 레이드에 피해를 준 사람이 보상을 받아요',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
        else
          Row(children: [
            Text('도전권 ${r.tickets}장', style: const TextStyle(color: AppColors.text, fontSize: 13)),
            const Spacer(),
            SizedBox(
              width: 150,
              child: GoldButton(
                key: Key(giant ? 'giantStart' : 'raidStart'),
                label: '도전하기',
                height: 42,
                fontSize: 16,
                onPressed: r.tickets > 0 && !c.guildBusy ? () => _fight(giant) : null,
              ),
            ),
          ]),
      ]),
    );
  }

  Future<void> _fight(bool giant) async {
    final b = c.startRaid(giant: giant);
    if (b == null) return _say('지금은 도전할 수 없어요', ok: false);
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => RaidBattleScreen(controller: c, battle: b, giant: giant)));
    if (mounted) await showAct4Pending(context, c);
  }

  // ───────────── 상점 탭

  Widget _shop(GuildView g) => OrnatePanel(
        key: const Key('guildShop'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('길드 상점', style: AppText.title(16)),
          const Text('등불 인장으로 사요 · 「등불 수호단」 장비는 레이드 재료도 들어요',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          for (final s in GuildRules.shop) _shopRow(s),
        ]),
      );

  Widget _shopRow(GuildShopInfo s) {
    final block = c.guildShopBlock(s);
    final Widget icon = switch (s) {
      GuildShopInfo(equip: final e?) => EquipIcon(base: e, size: 40),
      GuildShopInfo(deco: final d?) =>
        GuildDecoImage(d, size: 40),
      GuildShopInfo(icon: final i?) =>
        Image.asset(i, width: 34, errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on_rounded, color: AppColors.gold)),
      _ when s.item == GuildShopItem.matBundle => const MaterialIcon(MaterialId.hardWood, size: 34),
      _ => const Icon(Icons.badge_rounded, color: AppColors.goldBright, size: 30),
    };
    return Padding(
      key: Key('guildShopRow_${s.item.name}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 44, child: Center(child: icon)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
            if (s.mats.isNotEmpty)
              Text(s.mats.entries.map((e) => '${Materials.info(e.key).name} ${e.value}').join(' · '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            if (block != null && block != '등불 인장이 모자라요')
              Text(block, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
        FilledButton(
          key: Key('guildBuy_${s.item.name}'),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              disabledBackgroundColor: const Color(0x33E8C46A),
              disabledForegroundColor: AppColors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34)),
          onPressed: block == null && !c.guildBusy
              ? () async {
                  final e = await c.buyGuildShop(s);
                  if (!mounted) return;
                  _say(e ?? '${s.name}을(를) 샀어요', ok: e == null);
                }
              : null,
          child: Text('인장 ${s.seals}',
              style: TextStyle(color: block == null ? AppColors.goldInk : AppColors.textMuted, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({super.key, required this.label, required this.on, required this.onTap, this.dot = false});

  final String label;
  final bool on, dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0x55E8C46A) : const Color(0x22000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? AppColors.goldBright : const Color(0x44E8C46A)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: on ? AppColors.goldBright : AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
            if (dot) ...[
              const SizedBox(width: 4),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFE25D5D), shape: BoxShape.circle)),
            ],
          ]),
        ),
      );
}

class _Pick extends StatelessWidget {
  const _Pick({super.key, required this.on, required this.onTap, required this.child});

  final bool on;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? AppColors.goldBright : const Color(0x33FFFFFF), width: on ? 2 : 1),
          ),
          child: child,
        ),
      );
}

/// ★ 줄 (회관)
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.star, this.max = 4});

  final int star, max;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= max; i++)
          Icon(i <= star ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18, color: i <= star ? AppColors.goldBright : AppColors.textMuted),
      ]);
}

/// 공개 길드 목록 (검색 · 들어가기)
class _GuildListSheet extends StatefulWidget {
  const _GuildListSheet({required this.controller, required this.first, required this.onJoined});

  final AppController controller;
  final List<GuildListing> first;
  final VoidCallback onJoined;

  @override
  State<_GuildListSheet> createState() => _GuildListSheetState();
}

class _GuildListSheetState extends State<_GuildListSheet> {
  AppController get c => widget.controller;
  late List<GuildListing> _list = widget.first;
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Padding(
            key: const Key('guildList'),
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('공개 길드', style: AppText.title(18)),
              TextField(
                key: const Key('guildSearch'),
                controller: _q,
                style: const TextStyle(color: AppColors.text),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                    hintText: '길드 이름으로 찾기', hintStyle: TextStyle(color: AppColors.textMuted), isDense: true),
                onSubmitted: (q) async {
                  final l = await c.listGuilds(query: q);
                  if (mounted && l != null) setState(() => _list = l);
                },
              ),
              const SizedBox(height: 8),
              if (_list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('아직 공개 길드가 없어요', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                ),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final g in _list)
                    Padding(
                      key: Key('guildListing_${g.gid}'),
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        PartyFlag(emblem: g.emblem, color: g.color, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.name, style: const TextStyle(color: AppColors.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                            Text('Lv.${g.level} · ${g.members} / ${g.size}명',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        ),
                        FilledButton(
                          key: Key('guildListJoin_${g.gid}'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                          onPressed: g.members >= g.size || c.guildBusy
                              ? null
                              : () async {
                                  final ok = await c.joinGuild(gid: g.gid);
                                  if (!context.mounted) return;
                                  if (ok) {
                                    Navigator.pop(context);
                                    widget.onJoined();
                                  } else {
                                    showTopNotice(context, GuildRules.errorText(c.guildError ?? ''),
                                        icon: Icons.info_outline_rounded);
                                  }
                                },
                          child: const Text('들어가기', style: TextStyle(color: AppColors.goldInk)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// 길드 레이드 한 판 (정해진 턴, 준 피해가 길드로 합쳐짐)
class RaidBattleScreen extends StatefulWidget {
  const RaidBattleScreen({
    super.key,
    required this.controller,
    required this.battle,
    this.giant = false,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final Battle battle;
  final bool giant;
  final Duration tickInterval;

  @override
  State<RaidBattleScreen> createState() => _RaidBattleScreenState();
}

class _RaidBattleScreenState extends State<RaidBattleScreen> {
  AppController get c => widget.controller;
  bool _done = false;
  RaidResult? _result;

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

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    final r = await c.finishRaid(widget.battle);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final b = widget.battle;
    final boss = Monsters.info(b.foe.monster);
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('raidBattle'),
        backgroundColor: AppColors.deepNight,
        bottomNavigationBar: _done
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FrameButton(
                      key: const Key('raidBack'), label: '돌아가기', onPressed: () => Navigator.of(context).pop()),
                ),
              )
            : null,
        body: NightBackground(
          child: _done
              ? ListView(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                  children: [OrnateTopBar(title: boss.name), const SizedBox(height: 10), _resultView(b)],
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OrnateTopBar(title: '길드 레이드 · ${boss.name}', onBack: null),
                    const SizedBox(height: 10),
                    Expanded(
                      child: BattleView(
                        battle: b,
                        fit: true,
                        jobSkills: c.battleJobSlots,
                        emptySlots: c.skillPageOpen,
                        jobMp: () => c.jobMp,
                        onJobSkill: c.payBattleSkill,
                        onMasterySkill: c.payMasterySkill,
                        background: 'assets/images/bg_guildhall.webp',
                        onFinished: _finish,
                        tickInterval: widget.tickInterval,
                        playerName: c.profile.name,
                        look: c.profile.look,
                        vibrate: c.vibrate,
                        sound: c.sound,
                        hour: c.now.hour,
                        season: SeasonRules.of(c.now),
                        weapon: weaponKindOf(c.armory.wornIn(EquipSlot.weapon)?.base),
                        fast: c.fastBattle,
                        onFastChanged: c.setFastBattle,
                        onAutoChanged: (hp, cure) => c.setAutoUse(hpPercent: hp, cure: cure),
                        floorLabelOf: (x) =>
                            '남은 턴 ${(GuildRules.fightTicks - x.ticks).clamp(0, GuildRules.fightTicks)}',
                        counterOf: (x) => '피해 ${comma(x.dealtToFoe)}',
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _resultView(Battle b) {
    final r = _result;
    final g = c.guild;
    final v = widget.giant ? g?.giant : g?.raid;
    return OrnatePanel(
      key: const Key('raidResult'),
      ornament: true,
      child: Column(children: [
        MonsterPicture(monster: b.foe.monster, size: 110, defeated: v?.defeated ?? false),
        const SizedBox(height: 6),
        if (r == null)
          const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.goldBright))
        else if (r.error != null)
          KText(GuildRules.errorText(r.error!), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text))
        else ...[
          Text(r.defeatedNow ? '길드가 함께 쓰러뜨렸어요!' : '길드에 피해를 보탰어요',
              style: AppText.title(18, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          Text('이번 판 ${comma(r.damage)}', key: const Key('raidDealt'), style: AppText.title(26, color: AppColors.text)),
          if (v != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (1 - v.progress).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0x33FFFFFF),
                color: const Color(0xFFE25D5D),
              ),
            ),
            const SizedBox(height: 4),
            Text(v.defeated ? '레이드 탭에서 보상을 받으세요' : '남은 도전권 ${v.tickets}장',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ],
      ]),
    );
  }
}
