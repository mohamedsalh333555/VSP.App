// 🛡️ FIX: import must precede all block declarations in Kotlin DSL.
// Having it after plugins{} causes the 17 Java/Kotlin build warnings.
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
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
        // ✅ Production Unique Application ID for Google Play Store
        applicationId = "app.vsp.sports"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
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
            // RELEASE SIGNING: Uses the credentials loaded from android/key.properties.
            // Strict Invariant: Must fail immediately if key.properties is missing (no silent fallback to debug).
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                throw org.gradle.api.GradleException("FATAL: android/key.properties not found! Release builds MUST be signed with the production keystore.")
            }
            isMinifyEnabled = false          // Disabled to prevent MethodChannel & reflection crashes
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
