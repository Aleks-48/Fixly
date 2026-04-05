import java.util.Properties
import java.io.FileInputStream

// 1. Загрузка свойств из key.properties (делаем это один раз в самом верху)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ВНИМАНИЕ: Проверь, чтобы этот ID совпадал с ID в Google Play Console!
    namespace = "com.example.fixly_app" 
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // 2. Настройка подписи (Signing)
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            // Файл ищем в текущей папке (android/app/)
            val stFile = keystoreProperties.getProperty("storeFile")
            storeFile = if (stFile != null) file(stFile) else null
        }
    }

    defaultConfig {
        applicationId = "com.example.fixly_app"
        minSdk = 26 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Указываем использовать созданный выше конфиг "release"
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Для отладки используем стандартную подпись
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
        }
    }
}

flutter {
    source = "../.."
}