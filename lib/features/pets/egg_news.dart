import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/pet_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../village/shelter_screen.dart';
import 'pet_art.dart';

/// 묶음 75 #327: 알 이름 (정령이 떠나기 전에는 「신비한 알」)
String eggName(EggGrade g, {required bool farewell}) => farewell ? g.label : '신비한 알';

/// 전투 결과 보상 칸 맨 앞: 알 그림 크게 + 「○○을 얻었어요!」 + 흔들림 · 반짝임 (희귀 이상은 빛 더)
class EggGotBanner extends StatelessWidget {
  const EggGotBanner({super.key, required this.grade, required this.farewell, this.size = 76, this.nameOnly = false});

  /// 묶음 78 #361: 창 제목이 「알을 얻었어요!」이면 그림 아래는 등급 이름만
  final bool nameOnly;

  final EggGrade grade;
  final bool farewell;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = eggName(grade, farewell: farewell);
    final bright = grade != EggGrade.common;
    return Column(key: Key('eggGot_${grade.name}'), mainAxisSize: MainAxisSize.min, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        builder: (context, v, child) {
          // 처음 0.7초 흔들림, 그 뒤 빛이 퍼짐
          final shake = v < 0.5 ? math.sin(v * math.pi * 10) * (1 - v * 2) * 0.22 : 0.0;
          final glow = math.sin(math.min(1, v * 1.4) * math.pi / 2);
          return SizedBox(
            width: size * 1.7,
            height: size * 1.25,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: size * (1.1 + glow * (bright ? 0.5 : 0.25)),
                height: size * (1.1 + glow * (bright ? 0.5 : 0.25)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (bright ? const Color(0xFFFFE38A) : const Color(0xFFFFF3D6)).withValues(alpha: 0.55 * glow),
                    Colors.transparent,
                  ]),
                ),
              ),
              for (var i = 0; i < (bright ? 8 : 4); i++)
                Transform.translate(
                  offset: Offset(math.cos(i * 0.8 + v * 2) * size * 0.62 * glow, math.sin(i * 0.8 + v * 2) * size * 0.5 * glow),
                  child: Icon(Icons.auto_awesome, size: 10 + (i % 3) * 3.0, color: AppColors.goldBright.withValues(alpha: glow)),
                ),
              Transform.rotate(angle: shake, alignment: Alignment.bottomCenter, child: child),
            ]),
          );
        },
        child: EggArt(size: size, grade: grade, glowing: true),
      ),
      Text(nameOnly ? name : '${josa(name, '을/를')} 얻었어요!',
          key: const Key('eggGotLine'), style: AppText.title(16, color: AppColors.goldBright)),
    ]);
  }
}

/// 전투 밖(주간 의뢰 등)에서 알을 얻었을 때: 알 그림 작은 창
Future<void> showEggGotDialog(BuildContext context, AppController c, EggGrade grade) => showDialog<void>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('알을 얻었어요!', style: AppText.title(19)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          EggGotBanner(grade: grade, farewell: true, size: 64, nameOnly: true),
          const SizedBox(height: 6),
          const KText('펫 쉼터 알 부화장에서 품을 수 있어요',
              key: Key('eggGotHint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 14)),
        ]),
        actions: [
          TextButton(
            key: const Key('eggGotGo'),
            onPressed: () {
              Navigator.of(d).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShelterScreen(controller: c)));
            },
            child: const Text('알 부화장에서 품기'),
          ),
          TextButton(
            key: const Key('eggGotLater'),
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('나중에'),
          ),
        ],
      ),
    );
