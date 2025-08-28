plugins {
    id("com.android.application")
    id("kotlin-android")
    // O plugin do Flutter deve ser aplicado após os plugins do Android e Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bytechat.app"
    compileSdk = 34
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ADICIONADO para resolver o problema da dependência
        isCoreLibraryDesugaringEnabled = true
        // ---
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Especifique seu próprio ID único de Aplicativo (https://developer.android.com/studio/build/application-id.html ).
        applicationId = "com.bytechat.app"
        // Você pode atualizar os seguintes valores conforme as necessidades do seu aplicativo.
        // Para mais informações, consulte: https://flutter.dev/docs/deployment/android#review-the-gradle-configuration.
        minSdk = 21
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            // Adicione sua própria configuração de assinatura para o build de release.
            // Assinando com as chaves de depuração por enquanto, para que `flutter run --release` funcione.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ADICIONADO o bloco de dependências inteiro
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
