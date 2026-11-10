# 部分插件通过反射 / JNI 调用，R8 混淆后可能失效，这里统一保留
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.alexmercerind.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-keep class io.flutter.plugins.** { *; }

# 自用改造版已移除友盟统计，相关 keep / dontwarn 一并清理
-keepclassmembers class * {
    public <init>(org.json.JSONObject);
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 保留注解与原生方法名（JNI 依赖方法名匹配）
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepclasseswithmembernames class * {
    native <methods>;
}
