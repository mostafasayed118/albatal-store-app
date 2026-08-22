# ============================================================================
# ProGuard/R8 Rules — Al Batal Elite
# Reviewed: 2025-07-25
# Scope: Minimal rules required for Flutter + AndroidX release builds
# ============================================================================

# ---------------------------------------------------------------------------
# Flutter engine — must not be stripped or renamed
# ---------------------------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ---------------------------------------------------------------------------
# AndroidX — keep annotated classes used by reflection / manifest
# ---------------------------------------------------------------------------
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ---------------------------------------------------------------------------
# Google Play Services — Supabase / auth SDKs may pull these in
# ---------------------------------------------------------------------------
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ---------------------------------------------------------------------------
# Kotlin coroutines — keep Continuation and coroutine metadata
# ---------------------------------------------------------------------------
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# ---------------------------------------------------------------------------
# Data classes / model classes used with Gson / JSON serialization
# Keep any class annotated with @Keep (AndroidX annotation)
# ---------------------------------------------------------------------------
-keep @androidx.annotation.Keep class * { *; }

# ---------------------------------------------------------------------------
# Remove debug logging in release (optional, reduces APK size)
# ---------------------------------------------------------------------------
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# ---------------------------------------------------------------------------
# Generic: keep names needed for native method resolution
# ---------------------------------------------------------------------------
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---------------------------------------------------------------------------
# Google Play Core — Flutter engine references these but they're
# unused in our APK. Suppress missing class warnings.
# ---------------------------------------------------------------------------
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
