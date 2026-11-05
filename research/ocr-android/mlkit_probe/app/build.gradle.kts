plugins {
    id("com.android.application")
}

android {
    namespace = "dev.nihongo.mlkitprobe"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }
    buildToolsVersion = "36.1.0"

    defaultConfig {
        applicationId = "dev.nihongo.mlkitprobe"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Size measurement only (`assembleRelease -Pprobe.abiSplits=true`): R8 shrinking like a store build,
    // one APK per ABI = roughly what one phone downloads. The probe runs use the debug build.
    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
    splits {
        abi {
            isEnable = providers.gradleProperty("probe.abiSplits").isPresent
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }
}

dependencies {
    // Bundled models (shipped inside the APK), not the Play services download variants.
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20260814") // real org.json: android.jar only has stubs in JVM tests
}
