import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.cricket.cricket_stream_finder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cricket.cricket_stream_finder"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val props = Properties().apply {
                val f = file(System.getenv("MYAPP_GRADLE_PROPERTIES") ?: "${System.getProperty("user.home")}/.gradle/gradle.properties")
                if (f.exists()) load(f.inputStream())
            }
            storeFile = file(props.getProperty("MYAPP_RELEASE_STORE_FILE", System.getenv("MYAPP_RELEASE_STORE_FILE") ?: "~/.gradle/cricket_keystore.jks"))
            storePassword = props.getProperty("MYAPP_RELEASE_STORE_PASSWORD", System.getenv("MYAPP_RELEASE_STORE_PASSWORD") ?: "")
            keyAlias = props.getProperty("MYAPP_RELEASE_KEY_ALIAS", System.getenv("MYAPP_RELEASE_KEY_ALIAS") ?: "cricket")
            keyPassword = props.getProperty("MYAPP_RELEASE_KEY_PASSWORD", System.getenv("MYAPP_RELEASE_KEY_PASSWORD") ?: "")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
