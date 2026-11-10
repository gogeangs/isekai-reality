import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_config.dart';
import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/device/device_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../legal/legal_screen.dart';

/// 설정: 이름 · 정령 이름 · 데이터 삭제 · 제외 구역 요청 · 앱 정보
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, this.onBack});

  final AppController controller;

  /// 위쪽 톱니바퀴로 열었을 때 뒤로 가기
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          OrnateTopBar(title: '설정', onBack: onBack),
          const SizedBox(height: 8),
          _Section(
            title: '알림',
            children: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: controller.gather.notify,
                  onChanged: controller.setWalkNotify,
                  title: const Text('걸을 때 알림 (길가의 발견·떠돌이 상인)',
                      style: TextStyle(color: AppColors.text, fontSize: 14)),
                  subtitle: const Text('밤 10시~아침 7시에는 보내지 않아요',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ),
            ],
          ),
          // 11-10 #24: 이름·정령 이름 바꾸기는 프로필로 옮겼다
          // 11-10 D1: 긴 설명 대신 한 줄 + 목록 항목
          _Section(
            title: '제외 구역 요청',
            children: [
              const _Note('게임이 열리면 안 되는 장소 알리기'),
              _Row(
                label: '요청하기',
                value: '',
                onTap: () => _requestExclusion(context),
              ),
            ],
          ),
          _Section(
            title: '내 데이터',
            children: [
              const _Note('걸음과 위치 기록은 휴대폰에만 저장돼요'),
              const _Note('마법 돋보기 사진은 휴대폰 안에서만 감정하고, 게임에 남기지 않아요'),
              _Row(
                label: '자세히 보기',
                value: '',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const DataInfoScreen())),
              ),
              _Row(
                label: '휴대폰 설정 열기',
                value: '권한',
                onTap: () async {
                  final ok = await DeviceLinks.openAppSettings();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('휴대폰 설정 앱에서 이 앱을 찾아 주세요')));
                  }
                },
              ),
              _Row(
                label: '모든 기록 지우고 처음부터',
                value: '',
                danger: true,
                onTap: () => _confirmReset(context),
              ),
            ],
          ),
          _Section(
            title: '테스트 기록 보내기',
            children: [
              const _Note('하루별 기록을 복사해 설문에 붙여 주세요'),
              _Row(
                label: '기록 내보내기 (복사)',
                value: '',
                onTap: () async {
                  await Clipboard.setData(
                      ClipboardData(text: controller.exportRecordsCsv()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('기록을 복사했어요')),
                    );
                  }
                },
              ),
            ],
          ),
          _Section(
            title: '약관',
            children: [
              _Row(
                label: LegalDoc.privacy.title,
                value: '',
                onTap: () => LegalScreen.open(context, LegalDoc.privacy),
              ),
              _Row(
                label: LegalDoc.locationTerms.title,
                value: '',
                onTap: () => LegalScreen.open(context, LegalDoc.locationTerms),
              ),
            ],
          ),
          _Section(
            title: '앱 정보',
            children: [
              const _Row(label: '버전', value: kAppVersion),
              _Row(
                label: '오픈소스 라이선스',
                value: '',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: '이세계가 현실이라면?',
                  applicationVersion: kAppVersion,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _requestExclusion(BuildContext context) async {
    final ok = await DeviceLinks.openMail(
      to: kSupportContact,
      subject: '[제외 구역 요청] 이세계가 현실이라면?',
      body: _exclusionRequestText(),
    );
    if (ok || !context.mounted) return;
    // 메일 앱이 없으면 요청 내용을 복사해 둔다
    await Clipboard.setData(ClipboardData(text: _exclusionRequestText()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('메일 앱을 열 수 없어 요청 내용을 복사했어요. '
              '받는 곳: $kSupportContact')));
    }
  }

  String _exclusionRequestText() {
    final fix = controller.lastFix;
    final where = fix == null
        ? '(장소 이름이나 주소를 적어 주세요)'
        : '현재 위치 ${fix.point.lat.toStringAsFixed(5)}, '
            '${fix.point.lng.toStringAsFixed(5)}';
    return '장소: $where\n'
        '이유: \n\n'
        '(추모 공간, 학교, 병원처럼 게임이 열리면 안 되는 곳을 알려 주세요. '
        '확인 후 몬스터·전투·이벤트를 두지 않는 제외 구역으로 정해요.)';
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.night,
        title: const Text('모든 기록을 지울까요?',
            style: TextStyle(color: AppColors.goldBright)),
        content: const Text(
          '레벨, 칭호, 하루 기록, 밝힌 지도가 모두 사라지고 되돌릴 수 없어요. '
          '건강 앱의 원래 기록은 지워지지 않아요.',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('그만두기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE57373)),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 설정은 위에 열린 화면이라, 지운 뒤 첫 화면(각성)이 보이게 먼저 닫는다
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    await controller.resetAll();
  }

}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OrnatePanel(
       child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.title(18)),
          const SizedBox(height: 10),
          ...children,
        ],
       ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(keepAll(text),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      );
}

class _Row extends StatelessWidget {
  const _Row(
      {required this.label,
      required this.value,
      this.onTap,
      this.danger = false});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: danger ? const Color(0xFFE57373) : AppColors.text)),
          ),
          Text(value, style: const TextStyle(color: AppColors.textMuted)),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

/// 내 데이터 자세히 보기 (설정에서 옮겨 온 설명)
class DataInfoScreen extends StatelessWidget {
  const DataInfoScreen({super.key});

  static const _paras = [
    '걸음은 휴대폰 안에서만 계산하고 밖으로 보내지 않아요.',
    '위치는 앱을 보고 있을 때만 쓰고, 방문 기록과 밝힌 지도는 휴대폰에만 저장해요.',
    '마법 돋보기는 카메라 화면에서 얼굴의 위치만 휴대폰 안에서 찾아 장식을 붙여요. 얼굴 사진이나 얼굴 정보를 밖으로 보내지 않고, 게임 안에 저장하지도 않아요.',
    '감정한 사진은 「앨범에 저장」이나 「공유하기」를 눌렀을 때만 휴대폰 앨범이나 고른 앱으로 가요. 게임에는 어떤 종족을 감정했는지만 남아요.',
    '건강 앱·위치·알림·카메라·사진 권한은 휴대폰 설정에서 언제든 끌 수 있어요.',
    '설정의 「모든 기록 지우고 처음부터」를 누르면 이 앱에 저장된 기록이 모두 지워져요. 건강 앱의 원래 기록은 그대로예요.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightBackground(
        header: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              OrnateTopBar(
                  title: '내 데이터',
                  onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 12),
              OrnatePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p in _paras)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(keepAll(p),
                            style: const TextStyle(
                                color: AppColors.text, height: 1.45)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
