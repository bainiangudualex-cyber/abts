/// 统计封装（自用改造版已停用）。
///
/// 原实现依赖 `umeng_common_sdk`，它的 Kotlin 插件在 CI 的 Flutter 3.47.9
/// / 新版 Kotlin 下 `:umeng_common_sdk:compileReleaseKotlin` 编译失败，
/// 而匿名统计对本地自用没有任何价值。这里保留同名空实现：
/// 所有调用点（main / 播放页 / 搜索页 / 书架 …）一行都不用改，
/// 也不会再往任何第三方上报数据。
class AppAnalytics {
  AppAnalytics._();

  static Future<void> init() async {}

  static void onEvent(String name, [Map<String, dynamic>? params]) {}

  static void onPageStart(String name) {}

  static void onPageEnd(String name) {}
}
