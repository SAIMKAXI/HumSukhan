# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Sherpa-ONNX
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keep class com.k2fsa.sherpa.onnx.** { *; }
-dontwarn com.k2fsa.sherpa.onnx.**

# Speech to text
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }

# Flutter TTS
-keep class com.turtletreelabs.fluttertts.** { *; }
-keep class com.turtletreelabs.fluttertts.** { *; }

# Provider
-keep class me.alfian.** { *; }

# Vibration
-keep class com.benjaminwiebe.vibration.** { *; }

# HTTP / Networking
-keep class java.net.** { *; }
-keep class javax.net.** { *; }
-dontwarn java.net.**
-dontwarn javax.net.**

# WebSocket
-keep class org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# UUID
-keep class java.util.UUID { *; }

# JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# General
-dontwarn javax.annotation.**
-dontwarn sun.misc.Unsafe
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
