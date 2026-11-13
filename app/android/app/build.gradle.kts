import java.io.ByteArrayOutputStream
import java.util.Properties
import javax.inject.Inject

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
        // flutter_local_notifications (review reminders) uses java.time.
        isCoreLibraryDesugaringEnabled = true
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
    // lets both sit on one device with their own data, and the dev label tells
    // them apart on the home screen (AndroidManifest.xml: ${appLabel}).
    flavorDimensions += "channel"
    productFlavors {
        create("dev") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "시오리 dev"
        }
        create("prod") {
            dimension = "channel"
            manifestPlaceholders["appLabel"] = "시오리"
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
    // java.time for older Android, needed by the reminder plugin.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

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

// The dictionary assets are built, not committed: JMdict
// (tools/dict/build_app_asset.py) and the Korean glossary
// (tools/dict/build_ko_glossary.py). Debug and profile builds run without them; a
// release must carry them, matching their editions, with a recent JMdict
// (tools/dict/asset_check.py --release, which runs python3 from PATH).
abstract class CheckReleaseDictionary @Inject constructor(
    private val execOperations: ExecOperations,
) : DefaultTask() {
    @get:Internal abstract val assetDir: DirectoryProperty
    @get:Internal abstract val checkScript: RegularFileProperty

    /** Asset file name -> the command that builds it. */
    @get:Internal abstract val buildCommands: MapProperty<String, String>

    @TaskAction
    fun check() {
        val dir = assetDir.get().asFile
        val missing = buildCommands.get().filterKeys { name ->
            val file = dir.resolve(name)
            !file.isFile || file.length() == 0L
        }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Dictionary asset missing: ${missing.keys.joinToString { "assets/dict/$it" }}. " +
                    "Build it with: ${missing.values.distinct().joinToString(" and ") { "python3 $it" }}",
            )
        }
        val python = System.getenv("PATH").orEmpty().split(File.pathSeparator)
            .filter { it.isNotEmpty() }
            .map { File(it, "python3") }
            .firstOrNull { it.isFile && it.canExecute() }
            ?: throw GradleException(
                "python3 is not on PATH; the release dictionary check " +
                    "(tools/dict/asset_check.py) needs it. Install Python 3.",
            )
        val output = ByteArrayOutputStream()
        val result = execOperations.exec {
            commandLine(
                python.path, checkScript.get().asFile.path, "--release", "--engine", "android",
                "--dir", dir.path, "--decks-dir", File(dir.parentFile, "decks").path,
            )
            standardOutput = output
            errorOutput = output
            isIgnoreExitValue = true
        }
        val text = output.toString(Charsets.UTF_8).trim()
        if (result.exitValue != 0) {
            throw GradleException(text.ifEmpty { "tools/dict/asset_check.py --release failed (exit ${result.exitValue})." })
        }
        logger.lifecycle(text)
    }
}

val checkReleaseDictionary = tasks.register<CheckReleaseDictionary>("checkReleaseDictionary") {
    assetDir.set(rootProject.file("../assets/dict"))
    checkScript.set(rootProject.file("../../tools/dict/asset_check.py"))
    buildCommands.set(
        mapOf(
            "jmdict-full-lean.sqlite.gz" to "tools/dict/build_app_asset.py",
            "jmdict-full-lean.edition.json" to "tools/dict/build_app_asset.py",
            "ko-glossary.sqlite.gz" to "tools/dict/build_ko_glossary.py --source <krdict JSON zip>",
            "ko-glossary.edition.json" to "tools/dict/build_ko_glossary.py --source <krdict JSON zip>",
        ),
    )
}

// A release is signed with the upload key from android/key.properties.
tasks.named { it == "preProdReleaseBuild" }.configureEach {
    dependsOn(checkReleaseDictionary)
    doFirst {
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
