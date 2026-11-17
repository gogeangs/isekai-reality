import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/legal_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'legal_screen.dart';

/// 문서 한 줄 설명 (동의 창)
String consentLine(LegalKind k) => switch (k) {
      LegalKind.terms => '이용약관에 동의해요.',
      LegalKind.privacy => '걸음 수와 게임 기록을 휴대폰에서 처리하고, 로그인하면 서버에 백업하는 것에 동의해요.',
      LegalKind.location => '앱을 보는 동안 위치로 주변 몬스터를 찾는 것에 동의해요. 좌표는 저장하지 않아요.',
      LegalKind.operation => '운영정책을 확인했어요.',
    };

/// 체크 한 줄 ((필수) 글 + 「보기」)
class ConsentCheck extends StatelessWidget {
  const ConsentCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.text,
    this.label = '필수',
    this.doc,
    this.bold = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final String? label;
  final LegalKind? doc;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.gold,
            checkColor: AppColors.night,
            side: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                      TextSpan(children: [
                        if (label != null)
                          TextSpan(
                              text: '($label) ',
                              style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.w700)),
                        TextSpan(text: keepAll(text)),
                      ]),
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: bold ? 15.5 : 14,
                          height: 1.45,
                          fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
                  if (doc != null)
                    TextButton(
                      key: Key('consentView_${doc!.name}'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => LegalScreen.openKind(context, doc!),
                      child: Text('${doc!.title} 보기 ›',
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.gold)),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      );
}

/// 필수 문서 체크 묶음 (모두 동의 + 문서마다 한 줄). 처음 각성 · 다시 동의 창이 같이 씀
class ConsentList extends StatelessWidget {
  const ConsentList({super.key, required this.docs, required this.checked, required this.onChanged, this.extra});

  final List<LegalKind> docs;
  final Set<LegalKind> checked;
  final ValueChanged<Set<LegalKind>> onChanged;

  /// 문서 줄 아래에 붙는 것 (만 14세 확인 등)
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final all = docs.every(checked.contains);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ConsentCheck(
        key: const Key('consentAll'),
        value: all,
        label: null,
        bold: true,
        text: '모두 동의',
        onChanged: (v) => onChanged(v ? {...docs} : <LegalKind>{}),
      ),
      const Divider(color: Color(0x33E8C77A), height: 8),
      for (final k in docs)
        ConsentCheck(
          key: Key('consent_${k.name}'),
          value: checked.contains(k),
          doc: k,
          text: consentLine(k),
          onChanged: (v) => onChanged(v ? {...checked, k} : ({...checked}..remove(k))),
        ),
      if (extra != null) extra!,
    ]);
  }
}

/// 업데이트 뒤 처음 · 문서가 바뀐 뒤 처음 켤 때 동의 창 (기존 각성자)
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  AppController get c => widget.controller;
  Set<LegalKind> _checked = {};
  bool _age = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final need = c.consentNeeded;
    final docs = [for (final v in need) v.kind];
    final askAge = c.consentAskAge;
    final first = c.consent.docs.isEmpty;
    final ok = docs.every(_checked.contains) && (!askAge || _age) && !_busy;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      key: const Key('consentScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, 28),
          children: [
            RibbonHeading(first ? '이용 약관에 동의해 주세요' : '바뀐 약관에 동의해 주세요', size: 21),
            const SizedBox(height: 10),
            Text(
                keepAll(first
                    ? '아르카를 이어서 즐기려면 아래 약관에 동의해 주세요. 내용은 언제든 설정 → 약관 · 정책에서 다시 볼 수 있어요.'
                    : '아래 문서가 바뀌었어요. 바뀐 문서에 동의하면 이어서 할 수 있어요.'),
                style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.5)),
            if (!first)
              for (final v in need)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      keepAll('${v.kind.title} · ${LegalRules.dateLabel(v.effective)}부터'
                          '${v.summary.isEmpty ? '' : ' · ${v.summary}'}'),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
            const SizedBox(height: 12),
            OrnatePanel(
              child: ConsentList(
                docs: docs,
                checked: _checked,
                onChanged: (s) => setState(() {
                  _checked = s;
                  if (askAge) _age = docs.every(s.contains);
                }),
                extra: askAge
                    ? ConsentCheck(
                        key: const Key('consentAge'),
                        value: _age,
                        text: '만 14세 이상이에요.',
                        onChanged: (v) => setState(() => _age = v),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            GoldButton(
              key: const Key('consentAgree'),
              label: '동의하고 시작',
              onPressed: ok
                  ? () async {
                      setState(() => _busy = true);
                      await c.agreeLegal(need);
                      if (mounted) setState(() => _busy = false);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인할 때 백업 동의 (두 칸 모두 필수, 하나라도 빼면 로그인하지 않음). 동의하면 true
Future<bool> askBackupConsent(BuildContext context, AppController c) async {
  if (c.consent.backupAgreed) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => const _BackupConsent(),
  );
  if (ok != true) return false;
  await c.agreeBackup();
  return true;
}

class _BackupConsent extends StatefulWidget {
  const _BackupConsent();

  @override
  State<_BackupConsent> createState() => _BackupConsentState();
}

class _BackupConsentState extends State<_BackupConsent> {
  bool _a = false, _b = false;

  @override
  Widget build(BuildContext context) => GameAlert(
        key: const Key('backupConsent'),
        title: const Text('기록 백업에 동의해 주세요'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(keepAll('로그인하면 기록을 서버에 백업해 휴대폰을 바꿔도 이어서 할 수 있어요. 두 가지 모두 동의해야 로그인할 수 있어요.'),
              style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 6),
          ConsentCheck(
            key: const Key('backupConsent_server'),
            value: _a,
            text: '기록을 서버(서울)에 백업',
            doc: LegalKind.privacy,
            onChanged: (v) => setState(() => _a = v),
          ),
          ConsentCheck(
            key: const Key('backupConsent_steps'),
            value: _b,
            text: '하루 걸음 수와 게임 기록을 함께 저장',
            onChanged: (v) => setState(() => _b = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('그만두기')),
          TextButton(
            key: const Key('backupConsentOk'),
            onPressed: _a && _b ? () => Navigator.pop(context, true) : null,
            child: const Text('동의하고 로그인'),
          ),
        ],
      );
}

/// 문서가 곧 바뀐다는 배너 (닫으면 그 판은 다시 안 보임)
class LegalChangeBanner extends StatelessWidget {
  const LegalChangeBanner({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final v = controller.legalBanner;
    if (v == null) return const SizedBox.shrink();
    return Material(
      key: const Key('legalBanner'),
      color: const Color(0xEE1B1F45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => LegalScreen.openKind(context, v.kind),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            const Icon(Icons.description_outlined, color: AppColors.goldBright, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(keepAll('${LegalRules.dateLabel(v.effective)}부터 ${v.kind.title}이 바뀌어요. 눌러서 보기'),
                  style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.35)),
            ),
            IconButton(
              key: const Key('legalBannerClose'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
              onPressed: () => controller.dismissLegalBanner(v),
            ),
          ]),
        ),
      ),
    );
  }
}
