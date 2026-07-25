plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pe.oratoria.oratoria_kids"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pe.oratoria.oratoria_kids"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // MediaPipe's LLM inference requires 24+; the vosk_flutter_2 live-caption
        // plugin raises the floor to 30 (Android 11). Fine for the target A12
        // (Android 13 / API 33) and still covers essentially every phone from
        // 2021 on. flutter.minSdkVersion is lower on some Flutter releases and
        // the build fails late during native linking, so we clamp explicitly.
        minSdk = maxOf(flutter.minSdkVersion, 30)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    buildTypes {
        // Debug keeps no abiFilters so `flutter build apk --debug
        // --split-per-abi` can emit a small x86_64-only APK for the emulator
        // (abiFilters and per-abi splits are mutually exclusive in AGP).
        release {
            // No abiFilters: they are mutually exclusive with per-abi splits.
            // Build the demo APK with `flutter build apk --release
            // --split-per-abi` and ship app-arm64-v8a-release.apk (arm64-only,
            // the only ABI the MediaPipe/Gemma delegate supports, and leaner
            // than a fat APK).
            signingConfig = signingConfigs.getByName("debug")
            // R8 needs keep rules for flutter_gemma's MediaPipe references,
            // otherwise minification aborts. See proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
