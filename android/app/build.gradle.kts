import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val googleMapsApiKeyProvider = providers.gradleProperty("GOOGLE_MAPS_API_KEY")
    .orElse(providers.environmentVariable("GOOGLE_MAPS_API_KEY"))
    .orElse("")
val googleMapsApiKey =
    (keystoreProperties["googleMapsApiKey"] as String?) ?: googleMapsApiKeyProvider.get()
val hasReleaseKeystore = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    .all { (keystoreProperties[it] as String?)?.isNotBlank() == true }
val isReleaseBuild = gradle.startParameter.taskNames.any { taskName ->
    taskName.lowercase().contains("release") || taskName.lowercase().contains("bundle")
}

if (isReleaseBuild && googleMapsApiKey.isBlank()) {
    throw GradleException(
        "GOOGLE_MAPS_API_KEY is required for release builds. Add it to android/key.properties, a Gradle property, or the environment."
    )
}

android {
    namespace = "com.techxpark.parking"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.techxpark.parking"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseBuild && !hasReleaseKeystore) {
                throw GradleException(
                    "android/key.properties must define keyAlias, keyPassword, storeFile, and storePassword for release builds."
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
