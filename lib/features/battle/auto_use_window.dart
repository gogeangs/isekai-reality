import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 전투에서 자동으로 마시기 (11-11 #93): 전투·설정·가방 세 곳이 같은 설정을 쓴다.
/// 작은 금테 창. HP 기준(안 마심/30%/50%) · 상태 이상 풀기.
Future<void> showAutoUseWindow(
  BuildContext context, {
  required int hp,
  required bool cure,
  required void Function(int hp, bool cure) onChanged,
}) =>
    showDialog<void>(
      context: context,
      builder: (d) => _AutoUseWindow(hp: hp, cure: cure, onChanged: onChanged),
    );

/// 전투 물약 줄 끝 작은 표시: 「자동 50%」(+✚) / 「자동 끔」
String autoUseLabel(int hp, bool cure) {
  if (hp <= 0 && !cure) return '자동 끔';
  if (hp <= 0) return '자동 ✚';
  return cure ? '자동 $hp% ✚' : '자동 $hp%';
}

class _AutoUseWindow extends StatefulWidget {
  const _AutoUseWindow(
      {required this.hp, required this.cure, required this.onChanged});

  final int hp;
  final bool cure;
  final void Function(int hp, bool cure) onChanged;

  @override
  State<_AutoUseWindow> createState() => _AutoUseWindowState();
}

class _AutoUseWindowState extends State<_AutoUseWindow> {
  late int _hp = widget.hp;
  late bool _cure = widget.cure;

  void _set({int? hp, bool? cure}) {
    setState(() {
      _hp = hp ?? _hp;
      _cure = cure ?? _cure;
    });
    widget.onChanged(_hp, _cure);
  }

  @override
  Widget build(BuildContext context) {
    return GameAlert(
      key: const Key('autoUseWindow'),
      title: const Text('전투에서 자동으로 마시기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KText('던전·필드·원정 모두 같아요. 전투 한 번에 3개까지.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          const Text('HP가 이만큼 아래면 회복 물약',
              style: TextStyle(color: AppColors.text, fontSize: 14)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: [
            for (final v in const [0, 30, 50])
              ChoiceChip(
                key: Key('autoHp_$v'),
                label: Text(v == 0 ? '안 마심' : '$v%'),
                selected: _hp == v,
                onSelected: (_) => _set(hp: v),
                selectedColor: AppColors.gold,
                backgroundColor: const Color(0xFF1E2250),
                labelStyle: TextStyle(
                    color: _hp == v ? AppColors.night : AppColors.text,
                    fontWeight: FontWeight.w700),
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            key: const Key('autoCure'),
            contentPadding: EdgeInsets.zero,
            value: _cure,
            onChanged: (v) => _set(cure: v),
            title: const Text('상태 이상 풀기',
                style: TextStyle(color: AppColors.text, fontSize: 14)),
            subtitle: const Text('중독·화상·눈부심·빙결이면 맞는 물약을 마셔요',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}
