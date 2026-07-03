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

    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += listOf(
                "*/arm64-v8a/libpython*.so",
                "*/armeabi-v7a/libpython*.so",
                "*/x86/libpython*.so",
                "*/x86_64/libpython*.so",
            )
        }
    }

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
        val resolvedMinSdk = 24
        minSdk = resolvedMinSdk
        val resolvedTargetSdk = 35
        targetSdk = resolvedTargetSdk
        versionCode = flutterVersionCode
        versionName = flutterVersionName

        println("Gradle build config:")
        println("  minSdkVersion: $resolvedMinSdk")
        println("  targetSdkVersion: $resolvedTargetSdk")
        println("  versionCode: $flutterVersionCode")
        println("  versionName: $flutterVersionName")

// flet: split_per_abi 
        ndk {
            
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
            
        }
// flet: end of split_per_abi 
    }

// flet: android_signing 

    buildTypes {
        release {
// flet: android_signing 
            signingConfig = signingConfigs.getByName("debug")
// flet: end of android_signing 
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
