import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ключ подписи выпуска описан в android/key.properties (в git не попадает): путь к хранилищу, пароль, имя ключа.
// Если файла нет (сборка из исходников на чужом компьютере), выпуск подписывается отладочным ключом.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
// -PdebugSign: подписать выпуск отладочным ключом нарочно — чтобы поставить его поверх отладочной версии на своём телефоне.
val useReleaseKey = keystorePropertiesFile.exists() && !project.hasProperty("debugSign")

android {
    namespace = "uz.sado.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "uz.sado.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (useReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // Две сборки. «foss» — без сервисов Google, такой приложение было всегда. «gms» — с push-уведомлениями
    // через Google (Firebase Cloud Messaging); ей нужен файл google-services.json из консоли Firebase
    // рядом с этим файлом (в git он не попадает).
    // Библиотеки (движок Flutter, WebRTC) кладём в APK сжатыми: файл для скачивания выходит вдвое меньше
    // (около 16 МБ вместо 34). Цена — при установке телефон распаковывает их, и на диске приложение
    // занимает больше. Для раздачи APK напрямую с GitHub и через каталоги это выгоднее.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // Значения из google-services.json попадают в сборку как строки ресурсов.
    buildFeatures {
        resValues = true
    }

    flavorDimensions += "push"
    productFlavors {
        create("foss") {
            dimension = "push"
        }
        create("gms") {
            dimension = "push"
            // Настройки Firebase берём из файла сами, без плагина Google: нужны четыре значения.
            val config = file("google-services.json")
            if (config.exists()) {
                val root = JsonSlurper().parse(config) as Map<*, *>
                val project = root["project_info"] as Map<*, *>
                val client = (root["client"] as List<*>).map { it as Map<*, *> }.firstOrNull {
                    val info = it["client_info"] as Map<*, *>
                    (info["android_client_info"] as Map<*, *>)["package_name"] == "uz.sado.app"
                } ?: throw GradleException("В google-services.json нет приложения uz.sado.app")
                val key = ((client["api_key"] as List<*>).first() as Map<*, *>)["current_key"] as String
                resValue("string", "google_app_id", (client["client_info"] as Map<*, *>)["mobilesdk_app_id"] as String)
                resValue("string", "gcm_defaultSenderId", project["project_number"] as String)
                resValue("string", "project_id", project["project_id"] as String)
                resValue("string", "google_api_key", key)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (useReleaseKey) "release" else "debug")
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

// Сборку «gms» без настроек Firebase не собираем: push в ней молча не работал бы.
gradle.taskGraph.whenReady {
    val needsConfig = allTasks.any { it.project == project && it.name.contains("Gms") && it.name.startsWith("assemble") }
    if (needsConfig && !file("google-services.json").exists()) {
        throw GradleException("Для сборки gms положите google-services.json в android/app (см. README).")
    }
}

dependencies {
    // Push через Google — только в сборке «gms». В «foss» этих библиотек нет вовсе.
    "gmsImplementation"(platform("com.google.firebase:firebase-bom:35.2.0"))
    "gmsImplementation"("com.google.firebase:firebase-messaging")

    // Сканер QR-кода для входа: камера (CameraX) и разбор кода (ZXing). Обе библиотеки открытые,
    // работают на самом телефоне и не требуют сервисов Google.
    val camerax = "1.6.2"
    implementation("androidx.camera:camera-core:$camerax")
    implementation("androidx.camera:camera-camera2:$camerax")
    implementation("androidx.camera:camera-lifecycle:$camerax")
    implementation("androidx.camera:camera-view:$camerax")
    implementation("com.google.zxing:core:3.5.4")
    testImplementation("junit:junit:4.13.2")
}
