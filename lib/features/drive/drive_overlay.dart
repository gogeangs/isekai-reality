import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/drive_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 차량 속도로 움직일 때 화면 전체를 가린다 (11-11 #61).
/// 묻는 중: 「운전 중이 아닌 승객인가요?」, 운전 중·무응답: 「안전 운전하세요」.
class DriveOverlay extends StatefulWidget {
  const DriveOverlay({super.key, required this.controller});

  final AppController controller;

  @override
  State<DriveOverlay> createState() => _DriveOverlayState();
}

class _DriveOverlayState extends State<DriveOverlay> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant DriveOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (widget.controller.driveMode == DriveMode.asking) {
      _timer = Timer(DriveRules.askTimeout, widget.controller.driveTimeout);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final asking = c.driveMode == DriveMode.asking;
    return Material(
      color: const Color(0xF20B0D26),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(asking ? Icons.directions_car_rounded : Icons.do_not_touch_rounded,
                  size: 64, color: AppColors.goldBright),
              const SizedBox(height: 14),
              Text(asking ? '운전 중이 아닌 승객인가요?' : '안전 운전하세요',
                  key: const Key('driveTitle'),
                  textAlign: TextAlign.center,
                  style: AppText.title(24)),
              const SizedBox(height: 10),
              KText(
                  asking
                      ? '차를 타고 빠르게 움직이고 있어요. 승객이라면 계속할 수 있지만, '
                          '걸음·이동 보상은 없고 사냥·채집 보상은 줄어들어요.'
                      : '차가 멈추면 다시 함께해요. 운전 중에는 휴대폰을 보지 마세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.5)),
              const SizedBox(height: 22),
              if (asking) ...[
                GoldButton(
                  key: const Key('drivePassenger'),
                  label: '승객이에요',
                  onPressed: () => c.answerDrive(passenger: true),
                ),
                const SizedBox(height: 10),
                FrameButton(
                  key: const Key('driveDriving'),
                  label: '운전 중이에요',
                  onPressed: () => c.answerDrive(passenger: false),
                ),
              ] else
                TextButton(
                  onPressed: () => c.answerDrive(passenger: true),
                  child: const Text('사실 승객이에요',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 승객 모드 표시 (화면 위쪽 가운데)
class PassengerBadge extends StatelessWidget {
  const PassengerBadge({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xE61E2250),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.goldBright),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.airline_seat_recline_normal_rounded,
                size: 16, color: AppColors.goldBright),
            SizedBox(width: 4),
            Text('승객 모드 · 보상 줄어듦',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none)),
          ]),
        ),
        ),
      );
}
