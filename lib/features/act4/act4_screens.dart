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
import '../awakening/awakening_screen.dart' show IllustratedScene, SceneWho;
import '../battle/battle_view.dart';
import '../battle/hero_rig.dart' show weaponKindOf;
import '../party/party_flag.dart';
import '../settings/account_section.dart' show LoginButton, signInFlow;
import '../smithy/equipment_view.dart' show EquipIcon;
import '../town/material_view.dart';
import '../act5/erbard_screens.dart' show openErbard;

part 'act4_screens/guild_hall_members.dart';

part 'act4_screens/guild_hall_hall.dart';

part 'act4_screens/act4_scene.dart';
part 'act4_screens/guild_list.dart';
part 'act4_screens/raid_battle.dart';

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

  // ───────────── 4막 이야기 카드

  // ───────────── 길드가 없을 때

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

  // ───────────── 길드 탭

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

  // ───────────── 레이드 탭

  // ───────────── 상점 탭

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
