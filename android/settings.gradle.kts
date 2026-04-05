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
    // Поднимаем до 8.9.1, как просят ошибки в логе
    id("com.android.application") version "8.9.1" apply false
    // Поднимаем Kotlin до 2.1.0, чтобы соответствовать AGP
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
