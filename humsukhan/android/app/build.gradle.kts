import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key. Android only installs an update signed with the same key
// as the installed app, so every release must use this one key. CI passes
// it in environment variables; a local build can use android/key.properties.
val releaseKey = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
    System.getenv("ANDROID_KEYSTORE_PATH")?.let { setProperty("storeFile", it) }
    System.getenv("ANDROID_KEYSTORE_PASSWORD")?.let { setProperty("storePassword", it) }
    System.getenv("ANDROID_KEY_ALIAS")?.let { setProperty("keyAlias", it) }
    System.getenv("ANDROID_KEY_PASSWORD")?.let { setProperty("keyPassword", it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseKey.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.humsukhan.humsukhan"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.humsukhan.humsukhan"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without the release key (a developer's machine), fall back to
            // the debug key so `flutter run --release` still works. The
            // release workflow refuses to publish such a build.
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
