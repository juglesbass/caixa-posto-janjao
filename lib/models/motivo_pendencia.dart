/// Por que um PDF de fechamento ficou parado na fila do Google Drive.
///
/// O motivo é gravado junto da pendência, e não só exibido na hora: a fila
/// sobrevive ao fechamento do app, então na volta o banner precisa continuar
/// sabendo o que houve. Sem isso a interface só sabia dizer "sem internet" —
/// inclusive quando o celular estava em 5G e o problema era outro, o que faz o
/// operador desconfiar do sistema em vez de agir.
class MotivoPendencia {
  /// Falha real de rede: o pedido não chegou ao servidor
  static const String semConexao = 'sem_conexao';

  /// O servidor não respondeu a tempo. O PDF pode ter sido entregue mesmo
  /// assim: o app não tem como distinguir "não chegou" de "chegou e a resposta
  /// se perdeu".
  static const String servidorDemorou = 'servidor_demorou';

  /// O Google devolveu a tela de login em vez de executar o Apps Script,
  /// sinal de que a implantação não está como "Qualquer pessoa"
  static const String precisaLogin = 'precisa_login';

  /// O servidor respondeu, mas recusando o envio (4xx/5xx ou erro do script)
  static const String erroServidor = 'erro_servidor';

  /// Texto curto mostrado ao operador no banner da fila
  static String descricao(String? codigo) {
    switch (codigo) {
      case servidorDemorou:
        return 'O servidor demorou para responder. O PDF pode já ter sido entregue — reenvie para confirmar.';
      case precisaLogin:
        return 'O Google pediu login em vez de executar o script. Avise a gerência.';
      case erroServidor:
        return 'O servidor recusou o envio. Tente reenviar.';
      case semConexao:
        return 'Sem internet no momento do fechamento.';
      default:
        return 'Aguardando envio para o Google Drive.';
    }
  }
}
