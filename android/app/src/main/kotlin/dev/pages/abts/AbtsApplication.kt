package dev.pages.abts

import io.flutter.app.FlutterApplication

/**
 * App Application。
 *
 * 自用改造版已移除友盟统计：该 SDK 的 Kotlin 插件在 CI 的 Flutter 3.47
 * / 新版 Kotlin 下编译失败，且本地自用不需要匿名统计。
 * 保留 FlutterApplication 子类，避免改动 AndroidManifest 里的 android:name。
 */
class AbtsApplication : FlutterApplication()
