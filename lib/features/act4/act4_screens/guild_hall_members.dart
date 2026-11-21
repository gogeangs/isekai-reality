part of '../act4_screens.dart';

extension _GuildHallMembers on _GuildHallScreenState {
  AppController get c => widget.controller;

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
}
