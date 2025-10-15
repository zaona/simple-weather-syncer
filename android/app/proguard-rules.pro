# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Play Core (for Flutter deferred components)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Package Info Plus
-keep class io.flutter.plugins.packageinfo.** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# HTTP
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Xiaomi XMS Wearable (小米穿戴设备)
-keep class com.xiaomi.xms.wearable.** { *; }
-keep interface com.xiaomi.xms.wearable.** { *; }
-dontwarn com.xiaomi.xms.wearable.**

# General optimizations
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

# Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

