import 'package:audio_service/audio_service.dart';

import 'book_player.dart';
import 'media_controls.dart';

/// audio_service 桥接：把 BookPlayer 暴露为系统媒体会话，
/// 提供锁屏/通知栏控制、后台播放（Android MediaSession）
class BiliAudioHandler extends BaseAudioHandler {
  BiliAudioHandler() {
    playbackState.add(PlaybackState(
      controls: mediaControls(false),
      systemActions: mediaSystemActions,
      androidCompactActionIndices: mediaCompactIndices,
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
    ));
  }

  BookPlayer get _player => BookPlayer.instance;

  /// 乐观更新：media_kit 的 playing 状态是异步落地的，
  /// 等 BookPlayer._pushState 推过来会有肉眼可见的延迟，
  /// 表现就是「暂停键点下去不变播放」。按钮一按先立刻翻图标，
  /// 等真实播放动作完成后再由 BookPlayer 推一次权威状态校正。
  void _optimistic(bool playing) {
    playbackState.add(PlaybackState(
      controls: mediaControls(playing),
      systemActions: mediaSystemActions,
      androidCompactActionIndices: mediaCompactIndices,
      processingState: AudioProcessingState.ready,
      playing: playing,
      updatePosition: _player.currentPosition,
    ));
  }

  @override
  Future<void> play() async {
    _optimistic(true);
    await _player.resume();
    _player.notifyPlayState();
  }

  @override
  Future<void> pause() async {
    _optimistic(false);
    await _player.pause();
    _player.notifyPlayState();
  }

  /// 通知栏「词」按钮：通知 UI 层打开文稿面板。
  /// 不用 customEvent 的接口形态，避免不同 audio_service 版本编译差异。
  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == openLyricsAction) lyricRequest.value++;
    return null;
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.next();

  @override
  Future<void> skipToPrevious() => _player.previous();

  @override
  Future<void> fastForward() => _player.seekRelative(15);

  @override
  Future<void> rewind() => _player.seekRelative(-15);

  @override
  Future<void> stop() => _player.stop();
}
