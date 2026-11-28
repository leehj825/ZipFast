plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zipfast.zipfast"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zipfast.zipfast"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Lint's release-time check crashes on some toolchains and adds nothing to a
    // prerelease build. Run `./gradlew lint` by hand if you want the report.
    lint {
        checkReleaseBuilds = false
    }

    buildTypes {
        release {
            // Code shrinking (R8) is OFF: with the ads SDK it renamed Room classes, so the
            // WorkManager that the SDK starts at launch could not create its database and the
            // app died before its first screen. Flutter's Gradle plugin turns minify on, so it is
            // switched off here, after the plugin ran. The rules below still protect the
            // JNI-visible and reflection-loaded classes if shrinking is ever re-enabled.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Same net.sf.sevenzipjbinding API that android/engine-test exercises on the host JVM,
    // with the native .so files for Android ABIs bundled.
    implementation("com.github.omicronapps:7-Zip-JBinding-4Android:Release-16.02-2.02")
}

flutter {
    source = "../.."
}
