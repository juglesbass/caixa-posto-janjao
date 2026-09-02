import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções de configuração para o projeto Firebase do Posto Janjão
/// Permite diagnóstico consistente e inicialização em qualquer plataforma (Android, iOS, Web)
class DefaultFirebaseOptions {
  static const String defaultProjectId = 'caixa-posto-janjao';

  static Map<String, dynamic> get currentPlatform {
    if (kIsWeb) {
      return {
        'projectId': defaultProjectId,
        'authDomain': '$defaultProjectId.firebaseapp.com',
        'storageBucket': '$defaultProjectId.appspot.com',
      };
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return {
          'projectId': defaultProjectId,
          'storageBucket': '$defaultProjectId.appspot.com',
        };
      case TargetPlatform.iOS:
        return {
          'projectId': defaultProjectId,
          'storageBucket': '$defaultProjectId.appspot.com',
        };
      default:
        return {
          'projectId': defaultProjectId,
        };
    }
  }
}
