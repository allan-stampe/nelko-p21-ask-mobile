plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "dk.ask.nelko_p21_ask_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "dk.ask.nelko_p21_ask_mobile"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            // Experimental sideload build, NOT a production signing identity.
            // CI keys are ephemeral: replacement builds may require uninstall.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
flutter { source = "../.." }
