plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
