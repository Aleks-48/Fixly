plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Убедись, что этот namespace совпадает с твоим фактическим пакетом
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

    defaultConfig {
        // Твой уникальный ID приложения
        applicationId = "com.example.fixly_app"

        // ВНИМАНИЕ: Jitsi требует минимум 26. 
        // Если оставить flutter.minSdkVersion, будет ошибка сборки.
        minSdk = 26 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Конфигурация подписи для релизной сборки
            signingConfig = signingConfigs.getByName("debug")
            
            // Оптимизация (по желанию можно включить minifyEnabled true)
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Важно для Jitsi и некоторых других библиотек
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

dependencies {
    // Здесь можно добавлять нативные зависимости, если нужно
}