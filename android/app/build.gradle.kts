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
    compileSdk = 35
    // ndkVersion = "30.0.15729638"

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
        minSdk = 23
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
            // If the file is missing, it falls back to debug signing to prevent build failure during dev.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                logger.warn("⚠️ RELEASE SIGNING WARNING: key.properties not found. Building with debug keys. This will be REJECTED by Play Store.")
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
