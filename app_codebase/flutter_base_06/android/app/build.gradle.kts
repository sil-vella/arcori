import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.reignofplay.arcori"
    // Play requires target API 36 (Android 16). Flutter 3.32 still defaults to 35.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.reignofplay.arcori"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Play Billing 9.1.0 requires API 23. Flutter 3.32 still defaults to 21.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = maxOf(flutter.targetSdkVersion, 36)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Load keystore properties for release signing
    // Path: flutter_base_06/keystore.properties (from android/app/build.gradle.kts, go up 2 levels)
    val keystorePropertiesFile = file("../../keystore.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // Resolve keystore file path: upload-key.jks is in flutter_base_06/ (same dir as keystore.properties)
                val keystoreFileName = keystoreProperties["storeFile"] as String
                val keystoreFile = file("../../$keystoreFileName")
                if (keystoreFile.exists()) {
                    storeFile = keystoreFile
                    storePassword = keystoreProperties["storePassword"] as String
                } else {
                    throw GradleException(
                        "Release keystore not found: ${keystoreFile.absolutePath}"
                    )
                }
            }
        }
    }

    buildTypes {
        debug {
            // Use release keystore for debug builds too (so debug and release share same SHA-1)
            // This allows using the same OAuth client for both debug and release builds
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // If keystore.properties doesn't exist, fall back to default debug signing
        }
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Release builds require flutter_base_06/keystore.properties and upload-key.jks. " +
                        "Refusing to sign with the Android debug key."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
