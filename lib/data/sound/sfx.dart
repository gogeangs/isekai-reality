import 'package:audioplayers/audioplayers.dart';

/// 전투 효과음 (11-11 #75 확정). Oculus Audio Pack 01 (Meta), CC BY 4.0, 일부 편집.
/// 채집 효과음 (묶음 46 #233): Kenney Interface · Impact · RPG Audio, CC0.
enum SfxKind {
  hit,
  crit,
  superEffective,
  block,
  perfect,
  victory,
  defeat,
  // 채집
  pluck,
  ore,
  gem,
  saw,
  drop,
  brush,
  harvestPerfect,
  harvestFail,
  // 묶음 65: 공성전 「마지막 6시간」 북소리 (직접 합성)
  siegeDrum,
  // 묶음 69 #284: 정령이 말할 때 글자 소리 (풀 「사락」 · 불 「톡」 · 물 「똑」, 직접 합성)
  talkLeaf,
  talkFire,
  talkWater,
  // 묶음 70 #297: 가마솥에 재료가 「퐁」 (직접 합성)
  pong,
}

extension on SfxKind {
  String get file => switch (this) {
        SfxKind.hit => 'sfx/hit.m4a',
        SfxKind.crit => 'sfx/crit.m4a',
        SfxKind.superEffective => 'sfx/super.m4a',
        SfxKind.block => 'sfx/block.m4a',
        SfxKind.perfect => 'sfx/perfect.m4a',
        SfxKind.victory => 'sfx/victory.m4a',
        SfxKind.defeat => 'sfx/defeat.m4a',
        SfxKind.pluck => 'sfx/h_pluck.m4a',
        SfxKind.ore => 'sfx/h_ore.m4a',
        SfxKind.gem => 'sfx/h_gem.m4a',
        SfxKind.saw => 'sfx/h_saw.m4a',
        SfxKind.drop => 'sfx/h_drop.m4a',
        SfxKind.brush => 'sfx/h_brush.m4a',
        SfxKind.harvestPerfect => 'sfx/h_perfect.m4a',
        SfxKind.harvestFail => 'sfx/h_fail.m4a',
        SfxKind.siegeDrum => 'sfx/siege_drum.m4a',
        SfxKind.talkLeaf => 'sfx/talk_leaf.m4a',
        SfxKind.talkFire => 'sfx/talk_fire.m4a',
        SfxKind.talkWater => 'sfx/talk_water.m4a',
        SfxKind.pong => 'sfx/pong.m4a',
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
