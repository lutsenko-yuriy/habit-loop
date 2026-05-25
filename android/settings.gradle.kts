pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.2") apply false
    id("com.google.firebase.crashlytics") version("3.0.2") apply false
    // END: FlutterFire Configuration
    // Pin Kotlin version for Flutter's built-in Kotlin management (builtInKotlin=true).
    // Flutter 3.44's built-in Kotlin defaults to 2.0.0, but Firebase packages compiled
    // with Kotlin 2.2.0 are incompatible with 2.0.0. Declaring the version here with
    // apply false pins it to 2.2.20 without the app applying KGP itself.
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
