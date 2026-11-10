import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 一句文稿（SRT 的一个 cue）
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleLine(this.start, this.end, this.text);
}

/// 解析标准 SRT。兼容：无序号块、逗号或句点做毫秒分隔、
/// 多行文本、CRLF / CR / LF 混用、块间多个空行。
/// 只认时间轴行，其它内容一律当文本，解析不出来就返回空列表。
List<SubtitleLine> parseSrt(String raw) {
  final out = <SubtitleLine>[];
  final s = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final re = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );

  Duration toDur(String hh, String mm, String ss, String ms) => Duration(
        hours: int.parse(hh),
        minutes: int.parse(mm),
        seconds: int.parse(ss),
        milliseconds: int.parse(ms.padRight(3, '0')),
      );

  for (final block in s.split(RegExp(r'\n[ \t]*\n'))) {
    final rows = block
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rows.length < 2) continue;

    var timeIdx = -1;
    Match? found;
    for (var i = 0; i < rows.length; i++) {
      final m = re.firstMatch(rows[i]);
      if (m != null) {
        timeIdx = i;
        found = m;
        break;
      }
    }
    if (timeIdx < 0 || found == null) continue;

    final m = found;
    final text = rows.skip(timeIdx + 1).join('\n').trim();
    if (text.isEmpty) continue;

    out.add(SubtitleLine(
      toDur(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!),
      toDur(m.group(5)!, m.group(6)!, m.group(7)!, m.group(8)!),
      text,
    ));
  }

  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// 文稿仓储：按「视频 bvid + 分P cid」存到应用私有目录，
/// 一次导入、以后切到同一章自动加载。零新依赖（Clipboard / path_provider
/// / shared_preferences 都是项目已有依赖）。
class SubtitleStore {
  SubtitleStore._();
  static final SubtitleStore instance = SubtitleStore._();

  static const _prefOffset = 'abts_subtitle_offset_ms';

  Future<Directory> get _dir async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/subtitles');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _file(String bvid, int cid) async =>
      File('${(await _dir).path}/${bvid}_$cid.srt');

  /// 读本章文稿；没有导入过返回 null
  Future<List<SubtitleLine>?> load(String bvid, int cid) async {
    try {
      final f = await _file(bvid, cid);
      if (!await f.exists()) return null;
      final lines = parseSrt(await f.readAsString());
      return lines.isEmpty ? null : lines;
    } catch (_) {
      return null;
    }
  }

  /// 从剪贴板导入 SRT 全文。
  /// 用剪贴板而不是文件选择器，是为了不引入新的第三方插件，
  /// 让 GitHub Actions 首次构建尽量不因依赖版本失败。
  Future<int> importFromClipboard(String bvid, int cid) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = (data?.text ?? '').trim();
    if (text.isEmpty) {
      throw StateError('剪贴板是空的：先在电脑上复制 SRT 全文');
    }
    final lines = parseSrt(text);
    if (lines.isEmpty) {
      throw StateError('没解析出字幕：确认是标准 SRT（含 00:00:00,000 --> 00:00:02,000 时间轴）');
    }
    await (await _file(bvid, cid)).writeAsString(text, flush: true);
    return lines.length;
  }

  Future<void> clear(String bvid, int cid) async {
    try {
      final f = await _file(bvid, cid);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 全局时间偏移（毫秒）。ASR 时间戳常有几秒漂移，手动微调用。
  Future<int> offsetMs() async =>
      (await SharedPreferences.getInstance()).getInt(_prefOffset) ?? 0;

  Future<void> setOffsetMs(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefOffset, v.clamp(-600000, 600000));
  }
}
