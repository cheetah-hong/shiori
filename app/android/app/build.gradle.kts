import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the upload key named in android/key.properties (git-ignored,
// see key.properties.example). A relative storeFile is read from android/.
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val keyProperties: Properties? = rootProject.file("key.properties")
    .takeIf { it.isFile }
    ?.let { file -> Properties().apply { file.inputStream().use { load(it) } } }
val releaseStoreFile: File? = keyProperties?.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }

/** Why a release cannot be signed, or null when key.properties is complete. */
val releaseSigningProblem: String? = when {
    keyProperties == null -> "android/key.properties is missing."
    signingKeys.any { keyProperties.getProperty(it).isNullOrBlank() } ->
        "android/key.properties has no value for: " +
            signingKeys.filter { keyProperties.getProperty(it).isNullOrBlank() }.joinToString() + "."
    releaseStoreFile?.isFile != true -> "android/key.properties: storeFile does not point to a file."
    else -> null
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

    // Two flavors (docs/architecture.md, 5). `dev` bundles the development samples
    // and never builds for release; `prod` is the distributed app. The dev suffix
    // lets both sit on one device with their own data.
    flavorDimensions += "channel"
    productFlavors {
        create("dev") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
        }
        create("prod") {
            dimension = "channel"
        }
    }

    // Without a complete key.properties there is no release signing config, and
    // preProdReleaseBuild stops the build: a release is never signed with the debug key.
    if (releaseSigningProblem == null) {
        val props = keyProperties!!
        signingConfigs {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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

    // OcrGeometry (pieces, turns) runs as a plain JVM test: ./gradlew :app:testDevDebugUnitTest
    testImplementation("junit:junit:4.13.2")
}

// Release checks (docs/architecture.md, 5). Debug builds need none of these.

// The dev flavor bundles the development samples (assets/dev_samples/) and
// never builds for release.
tasks.named { it == "preDevReleaseBuild" }.configureEach {
    doFirst {
        throw GradleException(
            "The dev flavor bundles development samples (assets/dev_samples/) and never builds " +
                "for release. Build with --flavor prod.",
        )
    }
}

// The dictionary asset is built, not committed (tools/dict/build_app_asset.py).
// Debug builds run without it (no dictionary); a release must carry it.
// A release is signed with the upload key from android/key.properties.
val dictionaryAssets = listOf("jmdict-full-lean.sqlite.gz", "jmdict-full-lean.edition.json")
    .map { rootProject.file("../assets/dict/$it") }
tasks.named { it == "preProdReleaseBuild" }.configureEach {
    doFirst {
        val missing = dictionaryAssets.filter { !it.isFile || it.length() == 0L }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Dictionary asset missing: ${missing.joinToString { "assets/dict/${it.name}" }}. " +
                    "Build it with: python3 tools/dict/build_app_asset.py",
            )
        }
        releaseSigningProblem?.let { problem ->
            throw GradleException(
                "Release signing: $problem A release is never signed with the debug key. " +
                    "Copy android/key.properties.example to android/key.properties and fill it in " +
                    "(README.md: 배포 빌드).",
            )
        }
    }
}

// Whatever the flavor, the assets a release app carries must not include the
// development samples (pubspec.yaml lists them for the dev flavor only).
tasks.withType<Copy>().named { it.startsWith("copyFlutterAssets") && it.endsWith("Release") }
    .configureEach {
        doLast {
            val samples = destinationDir.walkTopDown()
                .filter { it.isDirectory && it.name == "dev_samples" }
                .firstOrNull()
            if (samples != null) {
                throw GradleException(
                    "The release app would contain assets/dev_samples/ ($name). " +
                        "Only the dev flavor may bundle them (pubspec.yaml). If pubspec.yaml is " +
                        "right, the files are left over from an earlier build: run flutter clean.",
                )
            }
        }
    }
