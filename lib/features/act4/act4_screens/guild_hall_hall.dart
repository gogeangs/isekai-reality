part of '../act4_screens.dart';

extension _GuildHallHall on _GuildHallScreenState {
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
