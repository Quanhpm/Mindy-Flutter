import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.1")
}

// Không bao giờ dùng debug key cho release. File này bị .gitignore.
val releaseKeysFile = rootProject.file("key.properties")
val releaseKeys = Properties().apply {
    if (releaseKeysFile.exists()) releaseKeysFile.inputStream().use { load(it) }
}
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseKeys = signingFields.all { !releaseKeys.getProperty(it).isNullOrBlank() }
if (releaseKeysFile.exists() && !hasReleaseKeys) {
    throw GradleException("Incomplete Android key.properties; fill all four signing fields.")
}
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.endsWith("Release") } && !hasReleaseKeys &&
        providers.gradleProperty("allowUnsignedRelease").orNull != "true") {
        throw GradleException("Release signing is missing. Configure android/key.properties. For an explicitly unsigned verification build, set ORG_GRADLE_PROJECT_allowUnsignedRelease=true.")
    }
}

android {
    namespace = "vn.mindy.mindy_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Giữ ID riêng để cài song song với bản React Native.
        applicationId = "vn.mindy.mindy_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("release") {
                storeFile = rootProject.file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("release")
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
