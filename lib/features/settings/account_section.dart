import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/cloud/cloud_auth.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';

/// 「마지막 백업 ○분 전」
String backupAgo(DateTime? at, DateTime now) {
  if (at == null) return '아직 없어요';
  final d = now.difference(at);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  return '${d.inDays}일 전';
}

/// 설정 「계정」 칸 (묶음 55 #245): 로그인 · 백업 · 로그아웃 · 계정 삭제
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.controller});

  final AppController controller;

  static const _muted = TextStyle(color: AppColors.textMuted, fontSize: 13.5);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final s = c.cloud;
          return Column(
            key: const Key('accountSection'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!c.cloudAvailable)
                const Text('로그인은 준비 중이에요. 기록은 지금처럼 이 휴대폰에 저장돼요.',
                    key: Key('accountSoon'), style: _muted)
              else if (!s.signedIn) ...[
                Text(keepAll('로그인하면 기록을 서버에 백업해요. 휴대폰을 바꾸거나 앱을 다시 깔아도 이어서 할 수 있어요.'),
                    style: _muted),
                const SizedBox(height: 10),
                for (final p in c.loginProviders) ...[
                  LoginButton(
                    provider: p,
                    busy: c.cloudBusy,
                    onPressed: () => signInFlow(context, c, p),
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                _line('로그인', '${s.label ?? ''} · ${s.provider == LoginProvider.apple ? 'Apple' : 'Google'}',
                    key: const Key('accountWho')),
                if (s.cancelledDelete)
                  InkWell(
                    key: const Key('accountDeleteCancelled'),
                    onTap: c.markDeleteCancelSeen,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('다시 로그인해서 계정 삭제를 취소했어요. (눌러서 닫기)',
                          style: TextStyle(color: AppColors.goldBright, fontSize: 13.5)),
                    ),
                  ),
                if (s.choosing) ...[
                  const SizedBox(height: 6),
                  Text(keepAll('두 기록 중 이어 할 기록을 아직 고르지 않았어요. 고르기 전까지는 백업하지 않아요.'),
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  GoldButton(
                    key: const Key('accountChoose'),
                    label: '기록 고르기',
                    height: 44,
                    onPressed: () => openRecordChoice(context, c),
                  ),
                ] else ...[
                  _line('마지막 백업', backupAgo(s.lastBackup, c.now), key: const Key('accountLast')),
                  const SizedBox(height: 6),
                  GoldButton(
                    key: const Key('accountBackup'),
                    label: c.cloudBusy ? '백업하는 중…' : '지금 백업',
                    height: 44,
                    onPressed: c.cloudBusy ? null : () => _backup(context),
                  ),
                ],
                const SizedBox(height: 4),
                const Text('평소엔 앱을 닫을 때와 10분마다 조용히 백업해요.', style: _muted),
                const SizedBox(height: 6),
                _row('로그아웃', key: const Key('accountSignOut'), onTap: () => _signOut(context)),
                _row('계정 삭제',
                    key: const Key('accountDelete'),
                    danger: true,
                    onTap: () => _delete(context)),
              ],
            ],
          );
        },
      );

  Widget _line(String a, String b, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(a, style: const TextStyle(color: AppColors.text)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(b,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted)),
          ),
        ]),
      );

  Widget _row(String label, {Key? key, required VoidCallback onTap, bool danger = false}) =>
      InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: danger ? AppColors.danger : AppColors.text)),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
        ),
      );

  Future<void> _backup(BuildContext context) async {
    final r = await controller.backupNow();
    if (!context.mounted) return;
    showTopNotice(
        context,
        switch (r) {
          CloudBackup.ok || CloudBackup.unchanged => '백업했어요',
          CloudBackup.offline => '인터넷에 연결되면 다시 해 볼게요',
          _ => '백업하지 못했어요. 잠시 뒤 다시 해 주세요',
        });
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('로그아웃할까요?'),
        content: Text(keepAll('나가기 전에 한 번 백업해요. 이 휴대폰의 기록은 그대로 남아요.'),
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(
              key: const Key('signOutYes'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true) return;
    await controller.signOutCloud();
    if (context.mounted) showTopNotice(context, '로그아웃했어요');
  }

  Future<void> _delete(BuildContext context) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('deleteDialog'),
        title: const Text('계정을 지울까요?', style: TextStyle(color: AppColors.goldBright)),
        content: Text(
          keepAll('7일 뒤 서버에 백업한 기록이 모두 지워져요. 7일 안에 다시 로그인하면 지우기가 취소돼요.\n\n'
              '이 휴대폰의 기록은 어떻게 할까요?'),
          style: const TextStyle(color: AppColors.text, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('그만두기')),
          TextButton(
              key: const Key('deleteKeepPhone'),
              onPressed: () => Navigator.pop(d, 1),
              child: const Text('휴대폰 기록은 남기기')),
          TextButton(
              key: const Key('deleteAll'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(d, 2),
              child: const Text('휴대폰 기록도 지우기')),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == 2 && context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    final ok = await controller.requestAccountDeletion(keepPhone: choice == 1);
    if (!context.mounted) return;
    showTopNotice(context,
        ok ? '계정 삭제를 요청했어요. 7일 뒤 지워져요' : '요청하지 못했어요. 인터넷을 확인하고 다시 해 주세요');
  }
}

/// 로그인 버튼 (Apple 은 Apple 안내대로 검정 바탕 · 흰 로고)
class LoginButton extends StatelessWidget {
  const LoginButton({super.key, required this.provider, required this.onPressed, this.busy = false});

  final LoginProvider provider;
  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final apple = provider == LoginProvider.apple;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        key: Key('login_${provider.name}'),
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: apple ? Colors.black : Colors.white,
          foregroundColor: apple ? Colors.white : const Color(0xFF1F1F1F),
          disabledBackgroundColor: apple ? Colors.black54 : Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: apple ? BorderSide.none : const BorderSide(color: Color(0xFF747775)),
          ),
          elevation: 0,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          apple
              ? const Icon(Icons.apple, size: 22)
              : const Text('G',
                  style: TextStyle(
                      color: Color(0xFF4285F4), fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Text(apple ? 'Apple로 로그인' : 'Google로 로그인',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// 로그인 → (둘 다 있으면) 기록 고르기
Future<void> signInFlow(BuildContext context, AppController c, LoginProvider p) async {
  final r = await c.signInCloud(p);
  if (!context.mounted) return;
  switch (r) {
    case CloudLogin.uploaded:
      showTopNotice(context, '로그인했어요. 이 휴대폰 기록을 서버에 백업했어요');
    case CloudLogin.restored:
      break; // 앱이 서버 기록으로 다시 켜짐
    case CloudLogin.choose:
      await openRecordChoice(context, c);
    case CloudLogin.cancelled:
      break;
    case CloudLogin.offline:
      showTopNotice(context, '인터넷에 연결된 뒤 다시 로그인해 주세요');
    case CloudLogin.failed:
    case CloudLogin.unavailable:
      showTopNotice(context, '로그인하지 못했어요. 잠시 뒤 다시 해 주세요');
  }
  if (context.mounted && c.cloud.cancelledDelete) {
    c.markDeleteCancelSeen();
    showTopNotice(context, '다시 로그인해서 계정 삭제를 취소했어요');
  }
}

Future<void> openRecordChoice(BuildContext context, AppController c) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => RecordChoiceScreen(controller: c)));

/// 처음 로그인했는데 휴대폰과 서버에 모두 기록이 있을 때: 이어 할 기록 고르기
class RecordChoiceScreen extends StatefulWidget {
  const RecordChoiceScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<RecordChoiceScreen> createState() => _RecordChoiceScreenState();
}

class _RecordChoiceScreenState extends State<RecordChoiceScreen> {
  AppController get c => widget.controller;
  RecordSummary? _server;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    c.serverSummary().then((s) {
      if (mounted) setState(() {
        _server = s;
        _loading = false;
      });
    });
  }

  static String _day(String d) => d.isEmpty ? '기록 없음' : d.replaceAll('-', '. ');

  Future<void> _pick(bool server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text(server ? '서버 기록으로 이어 할까요?' : '이 휴대폰 기록으로 이어 할까요?'),
        content: Text(
            keepAll(server
                ? '이 휴대폰의 기록 대신 서버 기록으로 바뀌어요. 지금 휴대폰 기록은 7일 동안 서버에 보관해요.'
                : '서버 기록 대신 이 휴대폰 기록을 백업해요. 지금 서버 기록은 7일 동안 보관해요.'),
            style: const TextStyle(color: AppColors.text, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(
              key: const Key('choiceYes'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('이어 하기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    final done = await c.chooseRecord(useServer: server);
    if (!mounted) return;
    if (!done) {
      showTopNotice(context, '고르지 못했어요. 인터넷을 확인하고 다시 해 주세요');
      return;
    }
    if (!server) showTopNotice(context, '이 휴대폰 기록으로 이어 해요');
    nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final phone = c.phoneSummary;
    return Scaffold(
      key: const Key('recordChoice'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, pad.bottom + 24),
          children: [
            OrnateTopBar(title: '기록 고르기', onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 10),
            Text(keepAll('이 휴대폰과 서버에 모두 기록이 있어요. 이어 할 기록을 하나 골라 주세요.'),
                style: const TextStyle(color: AppColors.text, fontSize: 15, height: 1.45)),
            const SizedBox(height: 4),
            Text(keepAll('고르지 않은 기록도 7일 동안 서버에 보관해요.'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 14),
            _card(
              key: const Key('choicePhone'),
              icon: Icons.smartphone_rounded,
              title: '이 휴대폰 기록',
              level: phone.level,
              day: _day(phone.lastDay),
              onPick: c.cloudBusy ? null : () => _pick(false),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              )
            else if (_server == null)
              const Text('서버 기록을 읽지 못했어요. 인터넷을 확인하고 다시 열어 주세요.',
                  style: TextStyle(color: AppColors.textMuted))
            else
              _card(
                key: const Key('choiceServer'),
                icon: Icons.cloud_rounded,
                title: '서버 기록',
                level: _server!.level,
                day: _day(_server!.lastDay),
                onPick: c.cloudBusy ? null : () => _pick(true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required Key key,
    required IconData icon,
    required String title,
    required int level,
    required String day,
    required VoidCallback? onPick,
  }) =>
      OrnatePanel(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.goldBright, size: 26),
              const SizedBox(width: 8),
              Text(title, style: AppText.title(18)),
            ]),
            const SizedBox(height: 8),
            Text('Lv.$level', style: AppText.title(26, color: AppColors.text)),
            Text('마지막으로 걸은 날 · $day',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5)),
            const SizedBox(height: 10),
            GoldButton(label: '이 기록으로 이어 하기', height: 44, onPressed: onPick),
          ],
        ),
      );
}
