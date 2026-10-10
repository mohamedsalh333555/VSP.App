// 🛡️ Keep imports before the plugins block.
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
val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val isTestReleaseApk = System.getenv("VSP_TEST_RELEASE_APK") == "true"

android {
    namespace = "app.vsp.sports"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

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
        minSdk = flutter.minSdkVersion
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
            // Test-only APKs use the runner's debug key when explicitly opted in.
            // This APK is installable for QA but is not Play Store/release-key signed.
            if (isTestReleaseApk) {
                signingConfig = signingConfigs.getByName("debug")
            } else if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isReleaseBuildRequested) {
                throw org.gradle.api.GradleException(
                    "Release signing key missing. For a test-only APK, set VSP_TEST_RELEASE_APK=true."
                )
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    applicationVariants.all {
        outputs.forEach { output ->
            val abiFilter = output.filters.find { it.filterType == com.android.build.OutputFile.ABI }
            if (abiFilter != null) {
                (output as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName = "vsp_app_${abiFilter.identifier}.apk"
            } else {
                (output as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName = "vsp_app_release.apk"
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
