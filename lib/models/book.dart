import 'chapter.dart';

/// 一本书（B 站视频），picture/bvid/作者/统计/多P章节
class Book {
  final String bvid;
  final int aid;
  final String title;
  final String pic;
  final int pages; // 分P数
  final int duration; // 总时长(秒)
  final String author;
  final int mid;
  final String authorFace;
  final String desc;
  final int play;
  final int like;
  final int coin;
  final int favorite;
  final int pubdate;
  final String upName;

  final List<Chapter>? chapters;

  Book({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.pic,
    this.pages = 1,
    this.duration = 0,
    this.author = '',
    this.mid = 0,
    this.authorFace = '',
    this.desc = '',
    this.play = 0,
    this.like = 0,
    this.coin = 0,
    this.favorite = 0,
    this.pubdate = 0,
    this.upName = '',
    this.chapters,
  });

  String get cleanTitle => title
      .replaceAll('<em class="keyword">', '')
      .replaceAll('</em>', '');

  /// 简洁书名，用于通知栏/锁屏这类空间紧张的位置。
  ///
  /// B 站视频标题普遍是 UP 主按 SEO 堆的关键词，例如
  /// 「异度旅社（远瞳）克苏鲁 多人在有声剧」。整条塞到通知副标题上
  /// 会比正文还长，和网易云那种「歌名 / 歌手」的两行结构完全不是一个观感。
  /// 这里按以下顺序收敛，尽量不误伤：
  ///   1. 去掉开头的【…】/[…] 标注（【完结】【合集】之类）
  ///   2. 在第一个括号、竖线、斜杠处截断
  ///   3. 在第一个空白处截断
  /// 截断结果为空时回退到 cleanTitle，保证永远不会显示空白。
  String get shortName {
    final base = cleanTitle.trim();
    if (base.isEmpty) return base;
    var t = base.replaceFirst(RegExp(r'^\s*[【\[][^】\]]*[】\]]\s*'), '');
    if (t.trim().isEmpty) t = base;
    final beforeBracket = t.split(RegExp(r'[（(\[【|｜/]')).first.trim();
    final firstWord = beforeBracket.split(RegExp(r'\s+')).first.trim();
    final out = firstWord.isNotEmpty ? firstWord : beforeBracket;
    return out.isNotEmpty ? out : base;
  }

  /// 归一化封面地址：`//i0.hdslb.com/...` 与 http 源统一转 https
  static String normalizePic(String input) {
    final u = input.trim();
    if (u.isEmpty) return u;
    if (u.startsWith('//')) return 'https:$u';
    if (u.startsWith('http://')) return 'https://${u.substring(7)}';
    return u;
  }

  /// 解析搜索接口的时长：可能是秒数，也可能是 "5152:33"（分:秒）/"1:02:03" 字符串
  static int parseDurationSeconds(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = '$v'.trim();
    if (s.isEmpty) return 0;
    final parts = s.split(':');
    if (parts.length >= 2) {
      var total = 0;
      for (final p in parts) {
        total = total * 60 + (int.tryParse(p.trim()) ?? 0);
      }
      return total;
    }
    return int.tryParse(s) ?? 0;
  }

  String get durationText {
    if (duration <= 0) return '';
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    final s = duration % 60;
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 从搜索结果构造
  factory Book.fromSearch(Map<String, dynamic> m) {
    return Book(
      bvid: m['bvid'] as String? ?? '',
      aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
      title: m['title'] as String? ?? '',
      pic: normalizePic(m['pic'] as String? ?? ''),
      pages: int.tryParse('${m['videos'] ?? 1}') ?? 1,
      duration: parseDurationSeconds(m['duration']),
      author: m['author'] as String? ?? '',
      mid: int.tryParse('${m['mid'] ?? 0}') ?? 0,
      play: int.tryParse('${m['play'] ?? 0}') ?? 0,
      pubdate: int.tryParse('${m['pubdate'] ?? 0}') ?? 0,
      desc: m['description'] as String? ?? '',
    );
  }

  /// 从详情（view）构造
  factory Book.fromView(Map<String, dynamic> m) {
    final owner = m['owner'] as Map? ?? {};
    final stat = m['stat'] as Map? ?? {};
    final pages = m['pages'] as List? ?? [];
    return Book(
      bvid: m['bvid'] as String? ?? '',
      aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
      title: m['title'] as String? ?? '',
      pic: normalizePic(m['pic'] as String? ?? ''),
      pages: pages.isEmpty ? 1 : pages.length,
      duration: int.tryParse('${m['duration'] ?? 0}') ?? 0,
      author: owner['name'] as String? ?? '',
      mid: int.tryParse('${owner['mid'] ?? 0}') ?? 0,
      authorFace: owner['face'] as String? ?? '',
      desc: m['desc'] as String? ?? '',
      play: int.tryParse('${stat['view'] ?? 0}') ?? 0,
      like: int.tryParse('${stat['like'] ?? 0}') ?? 0,
      coin: int.tryParse('${stat['coin'] ?? 0}') ?? 0,
      favorite: int.tryParse('${stat['favorite'] ?? 0}') ?? 0,
      pubdate: int.tryParse('${m['pubdate'] ?? 0}') ?? 0,
      upName: owner['name'] as String? ?? '',
      chapters: pages
          .map((e) => Chapter.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'bvid': bvid,
        'aid': aid,
        'title': cleanTitle,
        'pic': pic,
        'pages': pages,
        'duration': duration,
        'author': author,
        'mid': mid,
        'authorFace': authorFace,
        'desc': desc,
        'play': play,
      };

  factory Book.fromJson(Map<String, dynamic> m) => Book(
        bvid: m['bvid'] as String? ?? '',
        aid: int.tryParse('${m['aid'] ?? 0}') ?? 0,
        title: m['title'] as String? ?? '',
        pic: normalizePic(m['pic'] as String? ?? ''),
        pages: int.tryParse('${m['pages'] ?? 1}') ?? 1,
        duration: int.tryParse('${m['duration'] ?? 0}') ?? 0,
        author: m['author'] as String? ?? '',
        mid: int.tryParse('${m['mid'] ?? 0}') ?? 0,
        authorFace: m['authorFace'] as String? ?? '',
        desc: m['desc'] as String? ?? '',
        play: int.tryParse('${m['play'] ?? 0}') ?? 0,
      );
}