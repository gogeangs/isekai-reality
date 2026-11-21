part of '../act4_screens.dart';

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
