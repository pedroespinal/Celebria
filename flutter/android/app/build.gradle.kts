import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// Derive versionCode from versionName so Android always recognises a newer APK.
// "1.5.4" → 10504  |  "1.10.0" → 11000  |  "2.0.0" → 20000
val flutterVersionCode: Int = flutterVersionName.split(".")
    .mapNotNull { it.toIntOrNull() }
    .let { p ->
        (p.getOrElse(0) { 0 }) * 10000 +
        (p.getOrElse(1) { 0 }) * 100   +
        (p.getOrElse(2) { 0 })
    }.coerceAtLeast(1)

android {
    namespace = "com.flet.celebria"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets["main"].java.srcDir("src/main/kotlin")

    defaultConfig {
        applicationId = "com.flet.celebria"
        minSdk = 24
        targetSdk = 35
        versionCode = flutterVersionCode
        versionName = flutterVersionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Every release APK also gets a copy named with the version, e.g.
// build/app/outputs/flutter-apk/CelebriaV1.10.2.apk (Pedro's rule: the .apk
// must say which version it is). The original app-release.apk is kept as-is
// because the Flutter tool looks for that exact name after Gradle finishes.
// Older CelebriaV*.apk copies are removed so only the current one remains.
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val apkDir = layout.buildDirectory.dir("outputs/apk/release").get().asFile
        val src = File(apkDir, "app-release.apk")
        if (src.exists()) {
            val outDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            outDir.mkdirs()
            val name = "CelebriaV$flutterVersionName.apk"
            outDir.listFiles { f -> f.name.startsWith("CelebriaV") && f.name.endsWith(".apk") && f.name != name }
                ?.forEach { it.delete() }
            src.copyTo(File(outDir, name), overwrite = true)
            println("Versioned APK: ${File(outDir, name).absolutePath}")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
