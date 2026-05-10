import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.app"
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
        applicationId = "com.brightbund.brightbundapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "default"

    productFlavors {
        create("dev") {
            dimension = "default"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "BrightBund Dev")
        }
        create("prod") {
            dimension = "default"
            resValue("string", "app_name", "BrightBund")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Google Play Services Auth API Phone - required for SMS auto-retrieval
    implementation("com.google.android.gms:play-services-auth:20.7.0") 
    implementation("com.google.android.gms:play-services-auth-api-phone:18.1.0")

    configurations.all {
        resolutionStrategy {
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.core:core:1.15.0")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.activity:activity:1.9.3")
            // url_launcher_android 6.3.28 pulls browser 1.9.0, which requires AGP 8.9.1+.
            // Keep browser on 1.8.0 so the current AGP 8.7.0 toolchain can build.
            force("androidx.browser:browser:1.8.0")
        }
    }
}
