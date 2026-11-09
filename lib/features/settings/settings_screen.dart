import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_config.dart';
import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../legal/legal_screen.dart';

/// 설정: 이름 · 정령 이름 · 데이터 삭제 · 제외 구역 요청 · 앱 정보
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const OrnateTopBar(title: '설정'),
          const SizedBox(height: 8),
          _Section(
            title: '각성자와 정령',
            children: [
              _Row(
                label: '내 이름',
                value: profile.name,
                onTap: () async {
                  final name = await _askText(context,
                      title: '이름 바꾸기', initial: profile.name, maxLength: 10);
                  if (name != null) await controller.renameHero(name);
                },
              ),
              _Row(
                label: '정령 이름',
                value: profile.spiritName,
                onTap: () async {
                  final name = await _askText(context,
                      title: '정령 이름 바꾸기',
                      initial: profile.spiritName,
                      maxLength: 8);
                  if (name != null) await controller.renameSpirit(name);
                },
              ),
            ],
          ),
          _Section(
            title: '제외 구역 요청',
            children: [
              const Text(
                '추모 공간, 학교, 병원처럼 게임이 열리면 안 되는 곳을 알려 주세요. '
                '확인 후 몬스터·전투·이벤트를 두지 않는 제외 구역으로 정해요.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                kSupportContact.isEmpty
                    ? '요청 받는 곳: 테스트 시작 전에 안내해 드려요'
                    : '요청 받는 곳: $kSupportContact',
                style: const TextStyle(color: AppColors.text),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _exclusionRequestText()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('요청 내용을 복사했어요')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('요청 내용 복사'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      minimumSize: const Size(64, 44)),
                ),
              ),
            ],
          ),
          _Section(
            title: '내 데이터',
            children: [
              const Text(
                '걸음·수면은 휴대폰 안에서만 계산하고 밖으로 보내지 않아요. '
                '위치는 앱을 보고 있을 때만 쓰고, 방문 기록은 휴대폰에만 저장해요.\n'
                '건강 앱·위치 권한은 휴대폰 설정에서 언제든 끌 수 있어요.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('모든 기록 지우고 처음부터'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE57373),
                  side: const BorderSide(color: Color(0xFFE57373)),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
          _Section(
            title: '테스트 기록 보내기',
            children: [
              const Text(
                '테스트가 끝나면 하루별 기록(걸음·수면·던전·레벨 등)을 복사해 설문에 붙여 주세요. '
                '위치 좌표와 이름은 들어가지 않아요.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: controller.exportRecordsCsv()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기록을 복사했어요')),
                      );
                    }
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('기록 내보내기 (복사)'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.gold,
                      minimumSize: const Size(64, 44)),
                ),
              ),
            ],
          ),
          _Section(
            title: '약관과 날씨',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: profile.weatherEnabled,
                onChanged: controller.setWeatherEnabled,
                activeTrackColor: AppColors.gold,
                title: const Text('날씨로 불씨 색 바꾸기',
                    style: TextStyle(color: AppColors.text)),
                subtitle: const Text('약 1km 단위 위치로 날씨를 조회해요 (Open-Meteo)',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
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

  String _exclusionRequestText() {
    final fix = controller.lastFix;
    final where = fix == null
        ? '(장소 이름이나 주소를 적어 주세요)'
        : '현재 위치 ${fix.point.lat.toStringAsFixed(5)}, '
            '${fix.point.lng.toStringAsFixed(5)}';
    return '[제외 구역 요청] 이세계가 현실이라면?\n'
        '장소: $where\n'
        '이유: ';
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
    if (ok == true) await controller.resetAll();
  }

  static Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String initial,
    required int maxLength,
  }) {
    final text = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.night,
        title: Text(title, style: const TextStyle(color: AppColors.goldBright)),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: maxLength,
          style: const TextStyle(color: AppColors.text),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('그만두기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(text.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Text(label, style: const TextStyle(color: AppColors.text)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textMuted)),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
