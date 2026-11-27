# ---- 7-Zip-JBinding -------------------------------------------------------
# The native 7-Zip library (lib7-Zip-JBinding.so) finds these Java classes, methods
# and fields BY NAME through JNI. If R8 renames or removes them, the first RAR / 7Z /
# ISO / CAB open (or 7Z create) kills the app with a native "class not found" abort.
-keep class net.sf.sevenzipjbinding.** { *; }
-keep interface net.sf.sevenzipjbinding.** { *; }
-keepclassmembers class * implements net.sf.sevenzipjbinding.** { *; }
-dontwarn net.sf.sevenzipjbinding.**

# Our own bridge to it (called from Kotlin; keep names stable for stack traces too).
-keep class com.zipfast.zipfast.engine.** { *; }

-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*

# ---- Room / WorkManager (pulled in by the Google Mobile Ads SDK) -------------
# WorkManager starts at app launch (androidx.startup) and builds its Room database by
# reflection (WorkDatabase_Impl and the *_Impl DAOs). If R8 renames or strips them the app
# dies at launch, before any Dart code runs.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.startup.** { *; }
-keep class * extends androidx.startup.Initializer { *; }
-dontwarn androidx.work.**
