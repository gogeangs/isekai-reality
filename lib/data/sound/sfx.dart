import 'package:audioplayers/audioplayers.dart';

/// 전투 효과음 (11-11 #75 확정). Oculus Audio Pack 01 (Meta), CC BY 4.0, 일부 편집.
enum SfxKind { hit, crit, superEffective, block, perfect, victory, defeat }

extension on SfxKind {
  String get file => switch (this) {
        SfxKind.hit => 'sfx/hit.m4a',
        SfxKind.crit => 'sfx/crit.m4a',
        SfxKind.superEffective => 'sfx/super.m4a',
        SfxKind.block => 'sfx/block.m4a',
        SfxKind.perfect => 'sfx/perfect.m4a',
        SfxKind.victory => 'sfx/victory.m4a',
        SfxKind.defeat => 'sfx/defeat.m4a',
      };
}

/// 효과음을 낸다. [init] 을 부르기 전(테스트 등)에는 아무 소리도 내지 않는다.
/// 같은 소리는 한 플레이어가 다시 처음부터 내서, 2배속에서도 겹쳐 쌓이지 않는다.
class Sfx {
  Sfx._();

  static Map<SfxKind, AudioPlayer>? _players;

  /// 앱 시작 때 한 번. 무음 모드를 따르고 다른 앱 음악을 끊지 않는다.
  static Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
          AudioContextConfig(respectSilence: true).build());
      final m = <SfxKind, AudioPlayer>{};
      for (final k in SfxKind.values) {
        final p = AudioPlayer(playerId: 'sfx_${k.name}');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSource(AssetSource(k.file));
        m[k] = p;
      }
      _players = m;
    } catch (_) {
      _players = null; // 소리를 못 내도 게임은 그대로
    }
  }

  static void play(SfxKind k, {double volume = 0.8}) {
    final p = _players?[k];
    if (p == null) return;
    () async {
      try {
        await p.stop();
        await p.setVolume(volume);
        await p.resume();
      } catch (_) {}
    }();
  }
}
