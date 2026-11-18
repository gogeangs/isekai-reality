import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'building_upgrade.dart';

/// 시설 맨 위 마을 사람 (묶음 35): 금테 얼굴 + 이름·역할 + 한마디 말풍선.
/// 처음 만날 때 한 줄(한 번), 그 뒤엔 그 막의 평소 대사 두 줄을 번갈아.
/// 한마디는 화면을 열 때 한 번 정한다 (다시 그려도 바뀌지 않음).
/// 묶음 38 #213: 시설 안 정령 띠 대신 마을 사람이 안내한다 — 처음 만날 때 첫 줄 →
/// 상황 안내([situation]) → 그 밖엔 막 대사와 기본 안내([guide])를 번갈아.
/// 탭을 바꾸면 그 탭 안내([tabLine])로 바뀐다
class NpcHeader extends StatefulWidget {
  const NpcHeader({
    super.key,
    required this.controller,
    required this.npc,
    this.guide,
    this.situation,
    this.tabLine,
  });

  final AppController controller;
  final Npc npc;
  final String? guide;
  final String? situation;
  final String? tabLine;

  @override
  State<NpcHeader> createState() => _NpcHeaderState();
}

class _NpcHeaderState extends State<NpcHeader> {
  // 묶음 69 #289: 평소엔 얼굴 + 이름표만, 얼굴을 누르면 말풍선(위에 겹쳐 뜸, 아래를 밀지 않음).
  // 저절로 뜨는 대사(처음 만남 · 상황 · 새 부탁 · 한 번뿐인 말 · 탭 안내)는 그대로 열림
  late final ({String? auto, List<String> lines, String first}) _talk =
      widget.controller.npcTalk(widget.npc, guide: widget.guide, situation: widget.situation);
  late String _line = _talk.auto ?? _talk.first;
  late bool _open = _talk.auto != null;
  int _turn = 0;
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  /// 화면을 열 때마다 새로 보는 대사가 있으면 얼굴 위 작은 점 (열어 보면 사라짐)
  static final Set<String> _seen = {};

  bool get _unseen => _talk.lines.any((l) => !_seen.contains(l));

  @override
  void initState() {
    super.initState();
    _portal.show();
    if (_open) _seen.add(_line);
  }

  @override
  void didUpdateWidget(NpcHeader old) {
    super.didUpdateWidget(old);
    // 화면에 있는 동안 상황이 바뀌면 (예: 체크인해서 쉬는 중) 그 안내로 열림
    final s = widget.situation;
    if (s != null && s != old.situation) {
      _line = s;
      _open = true;
    }
    if (s == null && old.situation != null && widget.guide != null) _line = widget.guide!;
    final t = widget.tabLine;
    if (t != null && t != old.tabLine) {
      _line = t;
      _open = true;
    }
  }

  void _toggle() {
    setState(() {
      if (_open) {
        _open = false;
        return;
      }
      final lines = _talk.lines;
      final fresh = lines.where((l) => !_seen.contains(l)).toList();
      _line = fresh.isNotEmpty ? fresh.first : lines[_turn++ % lines.length];
      _seen.add(_line);
      _open = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = VillageRules.npc(widget.npc);
    final line = widget.tabLine != null && _line == widget.tabLine ? widget.tabLine! : _line;
    return Column(
      key: Key('npc_${widget.npc.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CompositedTransformTarget(
          link: _link,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (_) => CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              // 이름표 아래, 얼굴 오른쪽에 (아래 내용 위로 겹쳐 뜸)
              offset: const Offset(62, 30),
              child: Align(
                alignment: Alignment.topLeft,
                child: !_open
                    ? const SizedBox.shrink()
                    : LayoutBuilder(builder: (context, _) {
                        final w = MediaQuery.sizeOf(context).width;
                        return GestureDetector(
                          key: Key('npcBubble_${widget.npc.name}'),
                          onTap: () => setState(() => _open = false),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: (w - 62 - 28).clamp(160.0, 440.0)),
                            child: CodeBubble(
                              side: BubbleSide.left,
                              at: 16,
                              padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
                              child: KText(line,
                                  key: Key('npcLine_${widget.npc.name}'),
                                  style: const TextStyle(
                                      color: Color(0xFF3A2614), fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        );
                      }),
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                key: Key('npcFace_${widget.npc.name}'),
                onTap: _toggle,
                child: Stack(clipBehavior: Clip.none, children: [
                  NpcFace(npc: widget.npc, size: 58),
                  if (!_open && _unseen)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        key: Key('npcDot_${widget.npc.name}'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5484D),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              // 묶음 38 #214: 뒤 배경 그림 위에서도 또렷하게 어두운 반투명 띠
              Flexible(
                child: GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    key: Key('npcName_${widget.npc.name}'),
                    padding: const EdgeInsets.fromLTRB(8, 2, 10, 3),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0B0D26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(info.name, style: AppText.title(16, color: AppColors.goldBright)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(info.role,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFE6DCC4), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // 묶음 69 #286: 부탁 줄은 의뢰 게시판 「마을 사람 부탁」으로 옮김 · 건물 레벨업은 그대로
        Padding(
          padding: const EdgeInsets.only(left: 68),
          child: BuildingUpgradeBar(controller: widget.controller, npc: widget.npc),
        ),
      ],
    );
  }
}

/// 마을 사람 얼굴 (금테 원)
class NpcFace extends StatelessWidget {
  const NpcFace({super.key, required this.npc, this.size = 58});

  final Npc npc;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.abyss,
          border: Border.all(color: AppColors.goldBright, width: 2),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 8),
          ],
        ),
        child: ClipOval(
          child: Image.asset(VillageRules.npc(npc).asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  color: AppColors.goldBright)),
        ),
      );
}

