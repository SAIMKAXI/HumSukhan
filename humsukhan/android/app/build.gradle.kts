import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingPropertiesFile = rootProject.file("key.properties")
if (signingPropertiesFile.exists()) {
    signingPropertiesFile.inputStream().use(signingProperties::load)
}

fun signingValue(propertyName: String, envName: String): String? =
    signingProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envName)?.takeIf { it.isNotBlank() }

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
        create("release") {
            val storeFilePath = signingValue("storeFile", "HUMSUKHAN_KEYSTORE_FILE")
            val storePasswordValue = signingValue("storePassword", "HUMSUKHAN_KEYSTORE_PASSWORD")
            val keyAliasValue = signingValue("keyAlias", "HUMSUKHAN_KEY_ALIAS")
            val keyPasswordValue = signingValue("keyPassword", "HUMSUKHAN_KEY_PASSWORD")

            if (storeFilePath == null || storePasswordValue == null || keyAliasValue == null || keyPasswordValue == null) {
                throw GradleException(
                    "Release signing is not configured. Provide key.properties (storeFile, storePassword, keyAlias, keyPassword) " +
                        "or HUMSUKHAN_KEYSTORE_FILE/HUMSUKHAN_KEYSTORE_PASSWORD/HUMSUKHAN_KEY_ALIAS/HUMSUKHAN_KEY_PASSWORD."
                )
            }

            storeFile = file(storeFilePath)
            storePassword = storePasswordValue
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
