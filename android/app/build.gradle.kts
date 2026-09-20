// 🛡️ RELEASE/STORE READY: fail closed when a real signing key is absent.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.projectDir.resolve("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "app.vsp.sports"
    compileSdk = 36
    ndkVersion = "30.0.15729638"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "app.vsp.sports"
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            // Never ship a debug-signed release artifact.
            check(keystorePropertiesFile.exists()) {
                "Release signing is not configured. Create android/key.properties and provide a valid release keystore before building a store artifact."
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    applicationVariants.all {
        outputs.forEach { output ->
            val abiFilter = output.filters.find { it.filterType == com.android.build.OutputFile.ABI }
            if (abiFilter != null) {
                (output as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName =
                    "vsp_app_${abiFilter.identifier}.apk"
            } else {
                (output as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName =
                    "vsp_app_release.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

tasks.configureEach {
    if (name.contains("CMake")) {
        enabled = false
    }
}