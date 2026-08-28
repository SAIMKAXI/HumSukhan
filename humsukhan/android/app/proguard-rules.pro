# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Sherpa-ONNX
-keep class com.k2fsa.sherpa.onnx.** { *; }

# Speech to text
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter TTS
-keep class com.turtletreelabs.fluttertts.** { *; }

# Provider
-keep class me.alfian.** { *; }

# Vibration
-keep class com.benjaminwiebe.vibration.** { *; }

# General
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
-keepattributes *Annotation*
