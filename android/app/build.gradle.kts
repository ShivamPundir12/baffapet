// android/app/build.gradle.kts
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.baffapet.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.bafapet.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- Load keystore properties (expects a file named key.properties) ---
    // Try both project root and module dir to be flexible
    val keystoreProps = Properties().apply {
        val rootFile = rootProject.file("key.properties")
        val moduleFile = file("key.properties")
        val f = if (rootFile.exists()) rootFile else moduleFile
        if (f.exists()) {
            f.inputStream().use { load(it) }
        }
    }

    signingConfigs {
        if (keystoreProps.isNotEmpty()) {
            create("release") {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
            }
        }
        // Usually the default Android debug keystore is fine; uncomment only if you need custom debug signing:
        // create("debug") {
        //     keyAlias = "androiddebugkey"
        //     keyPassword = "android"
        //     storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")
        //     storePassword = "android"
        // }
    }

    buildTypes {
        getByName("release") {
            // Will be null if key.properties wasn't found; that's OK for now (unsigned build)
            signingConfig = signingConfigs.findByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // signingConfig = signingConfigs.getByName("debug") // only if you created one above
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
