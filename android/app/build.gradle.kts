import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de release.
//
// O arquivo android/key.properties NÃO é versionado (veja .gitignore). Quando
// ele existe, o APK sai assinado com a chave de verdade do posto; quando não
// existe, o build cai na chave de debug só para `flutter run --release`
// continuar funcionando na máquina de quem desenvolve.
//
// Isso importa no Android: a chave de debug muda a cada máquina e a cada runner
// do CI, e um APK assinado com chave diferente não instala por cima do anterior
// ("app não instalado"). Ou seja: sem chave fixa, atualizar o app obriga a
// desinstalar — e desinstalar apaga o banco local com os turnos.
//
// Como gerar a chave uma única vez:
//   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
//           -keysize 2048 -validity 10000 -alias upload
//
// E então criar android/key.properties com:
//   storePassword=...
//   keyPassword=...
//   keyAlias=upload
//   storeFile=upload-keystore.jks
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val temAssinaturaDeRelease = keystorePropertiesFile.exists()
if (temAssinaturaDeRelease) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.postojanjao.caixa_posto_janjao"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Exigido pelo flutter_local_notifications (v10+), mesmo sem usar
        // notificações agendadas. Sem isso o build do APK falha.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.postojanjao.caixa_posto_janjao"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (temAssinaturaDeRelease) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (temAssinaturaDeRelease) {
                signingConfigs.getByName("release")
            } else {
                // Sem key.properties: chave de debug, só para não travar o
                // desenvolvimento local. Não distribua um APK assinado assim.
                logger.warn("AVISO: android/key.properties ausente — APK de release sairá com a chave de DEBUG.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
