/// 章节（分P）
class Chapter {
  final int cid;
  final int page;
  final String part;
  final int duration; // 秒

  Chapter({
    required this.cid,
    required this.page,
    required this.part,
    this.duration = 0,
  });

  factory Chapter.fromMap(Map<String, dynamic> m) => Chapter(
        cid: int.tryParse('${m['cid'] ?? 0}') ?? 0,
        page: int.tryParse('${m['page'] ?? 0}') ?? 0,
        part: m['part'] as String? ?? '',
        duration: int.tryParse('${m['duration'] ?? 0}') ?? 0,
      );

  // ───────────────────────── 分P 名清洗 ─────────────────────────
  // B 站分P的 part 由 UP 主自由填写，大量是内部编号（yzts_98-1711-1740、
  // P98、98-1711、2026-11-10 ...）。原版把这些原样拼进「第 N 章 · xxx」，
  // 通知栏/播放页/章节列表就会露出乱码编号 —— 这是「通知栏难看」的
  // 最大来源，比图标问题明显得多。
  //
  // 判定原则：**宁可保留，不可误删**。只有确认为噪音才丢弃。

  /// 含中日韩文字 → 一定是有意义的名字
  static final RegExp _hasCjk =
      RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf\u3040-\u30ff\uac00-\ud7af]');

  /// 纯数字，与「第 N 章」重复
  static final RegExp _pureNumber = RegExp(r'^\d{1,5}$');

  /// P1 / p12 这类纯分P序号，同样与「第 N 章」重复
  static final RegExp _pIndex = RegExp(r'^[Pp]\s*\d{1,5}$');

  /// 全 ASCII（允许下划线/连字符/点/空格）
  static final RegExp _asciiOnly = RegExp(r'^[A-Za-z0-9_\-. ]+$');

  /// 标题自带序号（01xxx / 第 1 章 / P1 / 1 · xxx）时不再重复加序号。
  /// 与 book_detail_page 里原有的判定保持一致，改为对外暴露供模型复用。
  static final RegExp ownIndexPattern = RegExp(
    r'^\s*(?:第\s*[0-9一二三四五六七八九十百千零两]+\s*[章集回话期节]'
    r'|[Pp]\s*[0-9]{1,4}\b'
    r'|[0-9]{1,4}\s*[.·、:：)\-—]'
    r'|[0-9]{1,4}(?=\s*[^\s0-9]))',
  );

  /// 清洗后的分P名；判定为内部编号时返回空串。
  String get displayName {
    final raw = part.trim();
    if (raw.isEmpty) return '';
    if (_hasCjk.hasMatch(raw)) return raw;
    if (_pureNumber.hasMatch(raw)) return '';
    if (_pIndex.hasMatch(raw)) return '';
    if (_asciiOnly.hasMatch(raw)) {
      // 全 ASCII 且没有中文时，只有「含 2 段以上数字」才算内部编号；
      // EP01 / Vol.2 / OP / ED 这类有意义的名字会原样保留。
      final groups = RegExp(r'\d+').allMatches(raw).length;
      if (groups >= 2) return '';
    }
    return raw;
  }

  /// 播放器/通知栏标题，如「第 98 章」或「第 98 章 · 苏醒」。
  /// 分P名本身已带序号时不重复加前缀。
  String get title {
    final name = displayName;
    if (name.isEmpty) return '第 $page 章';
    if (ownIndexPattern.hasMatch(name)) return name;
    return '第 $page 章 · $name';
  }

  /// 章节列表里的一行文字：只要名字，清洗后为空则退回「第 N 章」
  String get shortTitle => displayName.isEmpty ? '第 $page 章' : displayName;

  String get durationText {
    if (duration <= 0) return '';
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
