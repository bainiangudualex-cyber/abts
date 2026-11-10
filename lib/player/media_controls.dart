import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// 通知栏「词」自定义动作的名字，BiliAudioHandler.customAction 按它分发。
const String openLyricsAction = 'openLyrics';

/// 通知栏「词」按钮：对应网易云媒体通知里那个字。
/// androidIcon 必须是 res/drawable 下的白色单色剪影，且已在 keep.xml 里保留，
/// 否则 release 包里会被资源压缩裁掉。
final MediaControl lyricControl = MediaControl.custom(
  androidIcon: 'drawable/ic_stat_lyrics',
  label: '词',
  name: openLyricsAction,
);

/// 通知栏点「词」→ UI 层打开文稿面板。
/// 只在同 isolate 内起效；播放页没打开时事件被忽略（点通知主体本就会拉起 App）。
final ValueNotifier<int> lyricRequest = ValueNotifier<int>(0);

/// 网易云式三键 + 一个自定义「词」动作，播放/暂停随状态翻转。
/// Android 紧凑视图最多只放 3 个动作，所以 compact 取 [0,1,2]，
/// 「词」只在展开视图出现 —— 这是系统限制，App 端无法突破。
List<MediaControl> mediaControls(bool playing) => [
      MediaControl.skipToPrevious,
      playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
      lyricControl,
    ];

final Set<MediaAction> mediaSystemActions = <MediaAction>{
  MediaAction.seek,
  MediaAction.seekForward,
  MediaAction.seekBackward,
  MediaAction.play,
  MediaAction.pause,
  MediaAction.stop,
};

const List<int> mediaCompactIndices = <int>[0, 1, 2];
