import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../player/book_player.dart';
import '../services/subtitle_store.dart';

/// 文稿面板：逐句高亮 + 自动滚动 + 点句跳转 + 时间偏移微调。
/// 数据源是 PC 端离线 ASR 生成的 SRT（D 方案），全本地、零网络请求。
class SubtitleSheet extends StatefulWidget {
  final BookPlayer player;
  final Book book;
  final Chapter chapter;

  const SubtitleSheet({
    super.key,
    required this.player,
    required this.book,
    required this.chapter,
  });

  static Future<void> show(
    BuildContext context, {
    required BookPlayer player,
    required Book book,
    required Chapter chapter,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: SubtitleSheet(player: player, book: book, chapter: chapter),
      ),
    );
  }

  @override
  State<SubtitleSheet> createState() => _SubtitleSheetState();
}

class _SubtitleSheetState extends State<SubtitleSheet> {
  static const double _rowHeight = 64.0;

  List<SubtitleLine> _lines = <SubtitleLine>[];
  int _offsetMs = 0;
  bool _loading = true;
  String? _hint;
  int _lastActive = -1;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final store = SubtitleStore.instance;
    final lines = await store.load(widget.book.bvid, widget.chapter.cid);
    final off = await store.offsetMs();
    if (!mounted) return;
    setState(() {
      _lines = lines ?? <SubtitleLine>[];
      _offsetMs = off;
      _loading = false;
      _hint = null;
      _lastActive = -1;
    });
  }

  Future<void> _import() async {
    try {
      final n = await SubtitleStore.instance
          .importFromClipboard(widget.book.bvid, widget.chapter.cid);
      await _reload();
      if (mounted) setState(() => _hint = '已导入 $n 句，本章以后自动加载');
    } catch (e) {
      if (mounted) setState(() => _hint = '$e');
    }
  }

  Future<void> _clear() async {
    await SubtitleStore.instance.clear(widget.book.bvid, widget.chapter.cid);
    await _reload();
    if (mounted) setState(() => _hint = '已清除本章文稿');
  }

  Future<void> _bumpOffset(int delta) async {
    final next = (_offsetMs + delta).clamp(-600000, 600000);
    await SubtitleStore.instance.setOffsetMs(next);
    if (mounted) setState(() => _offsetMs = next);
  }

  /// 二分找「开始时间 <= 当前播放位置」的最后一句；
  /// 落在两句之间的空白时不高亮，避免上句一直亮着。
  int _activeAt(Duration pos) {
    if (_lines.isEmpty) return -1;
    final t = pos + Duration(milliseconds: _offsetMs);
    var lo = 0;
    var hi = _lines.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lines[mid].start <= t) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (ans < 0) return -1;
    return _lines[ans].end >= t ? ans : -1;
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients) return;
    final target = (index * _rowHeight - 120).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        if (_hint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              _hint!,
              style: TextStyle(fontSize: 12, color: AppTheme.accent),
            ),
          ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    final sec = (_offsetMs / 1000).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '文稿同步',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.content_paste_go_outlined, size: 16),
                label: const Text('粘贴导入', style: TextStyle(fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清除', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              const Text('时间校准', style: TextStyle(fontSize: 12)),
              _offsetButton('-2s', -2000),
              _offsetButton('-0.5s', -500),
              Chip(
                label: Text('${sec}s', style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
              _offsetButton('+0.5s', 500),
              _offsetButton('+2s', 2000),
            ],
          ),
        ],
      ),
    );
  }

  Widget _offsetButton(String label, int delta) => ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        onPressed: () => _bumpOffset(delta),
      );

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subtitles_off_outlined,
                size: 40, color: AppTheme.textSub),
            const SizedBox(height: 12),
            Text(
              '本章还没有文稿',
              style: TextStyle(fontSize: 14, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            Text(
              '在电脑上用 tool/asr_to_srt.py 把音频离线转写成 SRT，\n'
              '复制 SRT 全文，再点右上角「粘贴导入」。\n'
              '导一次会按「本书 + 本章」存好，以后自动加载。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSub),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.player.positionTick,
      builder: (context, pos, _) {
        final active = _activeAt(pos);
        if (active >= 0 && active != _lastActive) {
          _lastActive = active;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollTo(active));
        }
        return ListView.builder(
          controller: _scroll,
          itemExtent: _rowHeight,
          itemCount: _lines.length,
          itemBuilder: (context, i) {
            final line = _lines[i];
            final on = i == active;
            return InkWell(
              onTap: () {
                final target =
                    line.start - Duration(milliseconds: _offsetMs);
                widget.player.seek(
                  target.isNegative ? Duration.zero : target,
                );
                Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: on
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: on ? AppTheme.accent : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  line.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: on ? 15 : 13,
                    height: 1.35,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? AppTheme.accent : AppTheme.textMain,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
