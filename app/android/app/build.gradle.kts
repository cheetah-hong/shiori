plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nihongoapp.shiori"
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
        applicationId = "com.nihongoapp.shiori"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Device OCR block: bundled on-device models, no network (OcrChannel.kt).
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    // EXIF rotation of the photo (works around vendor EXIF bugs the platform reader keeps).
    implementation("androidx.exifinterface:exifinterface:1.4.2")

    // OcrGeometry (pieces, turns) runs as a plain JVM test: ./gradlew :app:testDebugUnitTest
    testImplementation("junit:junit:4.13.2")
}

// Development samples (assets/dev_samples/) must never ship. Release builds stop
// here until they move behind a dev flavor (docs/architecture.md, 5절).
val pubspecFile = rootProject.file("../pubspec.yaml")
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        val listed = Regex("^\\s*-\\s*[\"']?assets/dev_samples/")
        val bundlesSamples = pubspecFile.readLines().any { listed.containsMatchIn(it) }
        if (bundlesSamples) {
            throw GradleException(
                "assets/dev_samples/ is for development only and is listed in pubspec.yaml. " +
                    "Remove it (or move it behind a dev flavor) before a release build.",
            )
        }
    }
}
