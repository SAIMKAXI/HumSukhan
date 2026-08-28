# Vosk Speech Recognition
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }

# Keep Vosk native methods
-keep class org.vosk.** { *; }
-keep class org.vosk.android.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Provider
-keep class me.alfian.** { *; }

# General
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
