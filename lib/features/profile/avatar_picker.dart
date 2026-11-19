import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'profile_screen.dart' show AvatarFace;

/// 묶음 75 #335: 「프로필 사진」 창 — 탭 주인공 · 펫 · 마을 사람 · 동료 · 배지,
/// 동그라미 4칸 격자, 지금 것은 금테 + ✓, 누르면 바로 바뀜
Future<void> showAvatarPicker(BuildContext context, AppController c,
    {AvatarTab tab = AvatarTab.hero}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.66,
      child: AvatarPicker(controller: c, tab: tab),
    ),
  );
}

class AvatarPicker extends StatefulWidget {
  const AvatarPicker(
      {super.key, required this.controller, this.tab = AvatarTab.hero});

  final AppController controller;
  final AvatarTab tab;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  late AvatarTab _tab = widget.tab;
  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final list = c.avatarChoices(_tab);
          // 떠나보낸 펫 · 모르는 열쇠면 주인공 얼굴이 지금 것
          final cur =
              c.avatarFace.startsWith('portrait_') ? 'hero' : c.avatarKey;
          return SafeArea(
            key: const Key('avatarPicker'),
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('프로필 사진',
                      textAlign: TextAlign.center, style: AppText.title(19)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final t in AvatarTab.values) ...[
                        ChoiceChip(
                          key: Key('avatarTab_${t.name}'),
                          label: Text(t.label),
                          selected: _tab == t,
                          onSelected: (_) => setState(() => _tab = t),
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.chipBg,
                          labelStyle: TextStyle(
                              color:
                                  _tab == t ? AppColors.night : AppColors.text,
                              fontWeight: FontWeight.w700),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: 6),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: KText(
                                switch (_tab) {
                                  AvatarTab.pet => '아직 함께하는 펫이 없어요.',
                                  AvatarTab.npc => '마을 사람과 단짝이 되면 고를 수 있어요.',
                                  AvatarTab.ally => '이야기 동료를 만나면 고를 수 있어요.',
                                  AvatarTab.title => '그림이 있는 칭호를 얻으면 고를 수 있어요.',
                                  AvatarTab.hero => '',
                                },
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textMuted)),
                          )
                        : GridView.count(
                            key: const Key('avatarGrid'),
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.78,
                            children: [
                              for (final x in list) _cell(x, x.key == cur),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _cell(AvatarChoice x, bool on) => GestureDetector(
        key: Key('avatar_${x.key}'),
        onTap: () => c.setAvatar(x.key),
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1D4A),
                    border: Border.all(
                        color: on
                            ? AppColors.goldBright
                            : AppColors.gold.withValues(alpha: 0.35),
                        width: on ? 3 : 1.2),
                    boxShadow: on
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.45),
                                blurRadius: 10)
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AvatarFace(face: x.face, look: c.profile.look),
                ),
              ),
              if (on)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    key: const Key('avatarOn'),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: kGoldGradient,
                      border: Border.all(color: AppColors.night, width: 1.5),
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 15, color: AppColors.goldInk),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(x.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: on ? AppColors.goldBright : AppColors.text,
                  fontSize: 11.5,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
