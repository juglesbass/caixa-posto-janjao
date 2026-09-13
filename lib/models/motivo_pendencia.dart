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

  /// Havia internet — a consulta de entrega chegou ao Google — mas o
  /// fechamento não apareceu na pasta. Não é falta de rede, e dizer isso
  /// levaria o operador a esperar um sinal que já está ali.
  static const String naoConfirmado = 'nao_confirmado';

  /// O PDF não chegou a ser montado neste aparelho (pedaço de código do PDF
  /// que não carregou, falha lendo o banco). Nada foi à rede, então culpar a
  /// internet seria mentir.
  static const String erroApp = 'erro_app';

  /// Gravada junto com o fechamento do turno, antes do envio começar. Só
  /// aparece se o envio não terminou — o app foi fechado, o iPhone suspendeu
  /// o PWA, a bateria acabou. Enquanto o envio está em andamento ela fica
  /// escondida do banner.
  static const String envioInterrompido = 'envio_interrompido';

  /// Texto curto mostrado ao operador no banner da fila
  static String descricao(String? codigo) {
    switch (codigo) {
      case servidorDemorou:
        return 'O servidor demorou para responder. O PDF pode já ter sido entregue — o app confere antes de reenviar.';
      case precisaLogin:
        return 'O Google pediu login em vez de executar o script. Avise a gerência.';
      case erroServidor:
        return 'O servidor recusou o envio. Tente reenviar.';
      case semConexao:
        return 'Sem internet no momento do fechamento.';
      case naoConfirmado:
        return 'O Google não confirmou a entrega. O app confere de novo antes de reenviar.';
      case erroApp:
        return 'O PDF não pôde ser gerado neste aparelho. Feche e abra o app; se continuar, avise a gerência.';
      case envioInterrompido:
        return 'O envio foi interrompido antes de terminar. O app confere e reenvia sozinho.';
      default:
        return 'Aguardando envio para o Google Drive.';
    }
  }
}
