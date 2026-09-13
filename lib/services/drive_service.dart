import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/motivo_pendencia.dart';
import 'database_service.dart';
import 'notification_service.dart';
// Diferido de propósito: o `pdf_service` arrasta os pacotes `pdf` e `printing`,
// que são o trecho mais pesado do pacote JavaScript do PWA, e nada disso é
// necessário para desenhar a tela de identificação. Ver [DriveService.aquecerPdf].
import 'pdf_service.dart' deferred as pdf_service;

/// Resposta da consulta "este fechamento chegou?" ao Apps Script.
enum EstadoEntrega {
  /// O Google confirmou: o fechamento está na pasta
  entregue,

  /// O Google respondeu, e o fechamento não está na pasta
  naoEncontrado,

  /// O Google respondeu, mas sem dizer se o PDF está lá: script publicado
  /// ainda sem a consulta, tela de login, página de erro. Havia internet.
  semSuporte,

  /// Nenhuma resposta: sem rede ou tempo esgotado
  semResposta,
}

class DriveService {
  static final http.Client _client = http.Client();

  /// Carrega antecipadamente o pedaço de código do PDF.
  ///
  /// `pdf_service` é importado com `deferred` para ficar fora do pacote inicial,
  /// o que encurta o primeiro carregamento no celular fraco. O preço seria o
  /// primeiro uso ter de buscar esse pedaço na rede — e fechamento de turno é
  /// exatamente o que não pode depender de sinal. Chamar isto na abertura paga a
  /// conta antes: o pedaço fica em memória muito antes de alguém fechar turno, e
  /// o service worker de precache também o deixa em disco para o modo offline.
  ///
  /// Falhar aqui não é erro: o carregamento apenas volta a ser sob demanda.
  static Future<void> aquecerPdf() async {
    try {
      await pdf_service.loadLibrary();
    } catch (e) {
      debugPrint('[DriveService] PDF será carregado sob demanda: $e');
    }
  }

  /// URL do webhook do Apps Script.
  ///
  /// A ordem de precedência é: configuração salva no banco
  /// ('google_drive_webhook_url') → `--dart-define=DRIVE_WEBHOOK_URL=...` no
  /// build → o valor abaixo. Como este repositório é público, o endereço aqui
  /// é conhecido por qualquer um: se precisar rotacionar o webhook, publique um
  /// novo Apps Script e informe a URL nova pelo dart-define ou pela tela de
  /// configuração, sem depender de mudar o código.
  static const String defaultWebhookUrl = String.fromEnvironment(
    'DRIVE_WEBHOOK_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbzes0dAFXK3_Us145YsnfKXAI_UzVjMHlVG4uK2-cYkxHy2f5M_VCaLEVEJhWOIvcVITQ/exec',
  );

  /// ID da Pasta Oficial (Fechamentos Posto Janjao) no Google Drive
  static const String pastaOficialId = '1lW3RYNyOzPz1R8A-vT9t9QWoLNvkADsC';
  static const String PASTA_OFICIAL_ID = pastaOficialId;

  /// ID da Pasta de Testes / Homologação no Google Drive
  static const String pastaTestesId = '1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM';
  static const String PASTA_TESTES_ID = pastaTestesId;
  static const String testFolderId = pastaTestesId;

  /// Chave de persistência do Modo Teste
  static const String keyModoTeste = 'modo_teste_ativo';

  /// Notifier reativo para atualizar a interface imediatamente quando o Modo Teste for alterado
  static final ValueNotifier<bool> modoTesteNotifier = ValueNotifier<bool>(false);

  /// Inicializa o estado do Modo Teste a partir do SharedPreferences
  static Future<bool> inicializarModoTeste() async {
    return isModoTeste();
  }

  /// Verifica se o Modo Teste está ativo
  static Future<bool> isModoTeste() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ativo = prefs.getBool(keyModoTeste) ?? false;
      modoTesteNotifier.value = ativo;
      return ativo;
    } catch (_) {
      return modoTesteNotifier.value;
    }
  }

  /// Ativa ou desativa o Modo Teste e persiste a escolha
  static Future<void> setModoTeste(bool ativo) async {
    modoTesteNotifier.value = ativo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyModoTeste, ativo);
    } catch (_) {}
  }

  /// Detecta a tela de login do Google devolvida no lugar da execução do script.
  ///
  /// É o falso positivo mais perigoso do fluxo: se a implantação do Apps Script
  /// estiver como "Qualquer pessoa **com conta Google**" em vez de "Qualquer
  /// pessoa", o Google responde **HTTP 200** com a página de login. Tratar isso
  /// como sucesso fazia o app anunciar "entregue" e apagar a pendência, sem que
  /// nada tivesse chegado à pasta do gerente.
  static bool _pareceTelaDeLogin(String body) {
    final b = body.toLowerCase();
    return b.contains('accounts.google.com') ||
        b.contains('servicelogin') ||
        b.contains('signin/v2') ||
        b.contains('faça login') ||
        (b.contains('<html') && b.contains('sign in'));
  }

  /// Detecta a página de erro que o Apps Script devolve quando a execução quebra
  static bool _pareceErroDeExecucao(String body) {
    final b = body.toLowerCase();
    return b.contains('script function not found') ||
        b.contains('ocorreu um erro') ||
        b.contains('exception:') ||
        b.contains('typeerror') ||
        b.contains('errorpage');
  }

  /// Avalia se a resposta HTTP do upload representa entrega real no Drive.
  ///
  /// Suporta 2xx, os redirecionamentos 3xx típicos do Apps Script e confirmação
  /// textual/JSON no corpo — mas recusa explicitamente a tela de login e a página
  /// de erro do Google, que também chegam como 200.
  static bool isRespostaSucesso(http.Response response) {
    final status = response.statusCode;
    final body = response.body;

    // Uma tela de login ou de erro nunca é entrega, qualquer que seja o status
    if (body.isNotEmpty && (_pareceTelaDeLogin(body) || _pareceErroDeExecucao(body))) {
      return false;
    }

    // 1. Respostas HTTP 2xx (Sucesso explícito)
    if (status >= 200 && status < 300) {
      // Se houver corpo em JSON, certifica-se de que não é uma mensagem de erro explícita do Apps Script
      try {
        final bodyTrim = body.trim();
        if (bodyTrim.startsWith('{') && bodyTrim.endsWith('}')) {
          final decoded = jsonDecode(bodyTrim);
          if (decoded is Map) {
            final erroExplicito = decoded['status'] == 'error' ||
                decoded['success'] == false ||
                decoded['error'] != null;
            if (erroExplicito) {
              return false;
            }
          }
        }
      } catch (_) {
        // Se não for JSON (ex: texto simples ou resposta vazia), 2xx é sucesso
      }
      return true;
    }

    // 2. Respostas HTTP 3xx (Redirecionamentos típicos do Google Apps Script)
    // O Apps Script executa o doPost() ANTES de devolver o 302. O 302 prova que o
    // script rodou; o que ele respondeu fica no destino do redirect, que
    // _executarPostWebhook segue. Se esse passo se perde, quem decide é a
    // consulta de entrega (ver confirmacaoPerdida).
    if (status >= 300 && status < 400) {
      return true;
    }

    // 3. Fallback de verificação de palavras-chave no corpo
    final bodyLower = body.toLowerCase();
    if (bodyLower.contains('success') ||
        bodyLower.contains('"status":"ok"') ||
        bodyLower.contains('sucesso')) {
      return true;
    }

    return false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONFIRMAÇÃO DE ENTREGA
  //
  // O app não consegue distinguir "o PDF não chegou" de "chegou e a resposta
  // se perdeu": espera esgotada, sinal que cai no meio, o iPhone suspendendo o
  // PWA. Antes, nesses casos, a tela dizia "falta de conexão com a internet" e
  // o operador reenviava um fechamento que já estava na pasta. Agora, na
  // dúvida, o app pergunta ao Apps Script. Nada é apagado nem substituído: a
  // consulta é só leitura.
  // ──────────────────────────────────────────────────────────────────────────

  /// Endereço da consulta "este fechamento chegou?" no mesmo Apps Script.
  static Uri montarUrlVerificacao(String webhookUrl, String authHash) {
    final base = Uri.parse(webhookUrl);
    return base.replace(queryParameters: {
      ...base.queryParameters,
      'verificar': authHash,
    });
  }

  /// Lê a resposta da consulta de entrega.
  ///
  /// Só vale a consulta de verdade (`verificacao: true`). O health check do
  /// script antigo, a tela de login e as páginas de erro também chegam como
  /// 200 — viram [EstadoEntrega.semSuporte]: houve resposta, mas sem dizer se o
  /// PDF está lá.
  static EstadoEntrega interpretarVerificacao(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return EstadoEntrega.semSuporte;
    }
    try {
      final decoded = jsonDecode(response.body.trim());
      if (decoded is Map && decoded['verificacao'] == true) {
        if (decoded['encontrado'] == true) return EstadoEntrega.entregue;
        if (decoded['encontrado'] == false) return EstadoEntrega.naoEncontrado;
      }
    } catch (_) {}
    return EstadoEntrega.semSuporte;
  }

  /// Pergunta UMA vez ao Apps Script se o fechamento [authHash] já está na pasta.
  static Future<EstadoEntrega> verificarEntrega(String webhookUrl, String authHash) async {
    if (authHash.trim().isEmpty) return EstadoEntrega.semResposta;
    try {
      final response = await _client
          .get(montarUrlVerificacao(webhookUrl, authHash))
          .timeout(const Duration(seconds: 15));
      return interpretarVerificacao(response);
    } catch (_) {
      return EstadoEntrega.semResposta;
    }
  }

  /// Esperas entre as consultas depois de um envio sem confirmação no
  /// fechamento do turno. Quando o app desiste de esperar, o Google às vezes
  /// ainda está gravando; perguntar só uma vez daria "não encontrado" cedo
  /// demais. Somam 24s, e param na hora em que a resposta chega.
  static const List<Duration> esperasConfirmacao = [
    Duration.zero,
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];

  /// Consulta repetida, com [esperas], até o fechamento aparecer.
  ///
  /// Para cedo quando esperar não muda nada: script sem a consulta, ou a
  /// primeira pergunta sem resposta nenhuma (sem rede, prender o operador
  /// olhando a tela não ajuda).
  static Future<EstadoEntrega> confirmarEntrega(
    String webhookUrl,
    String authHash, {
    List<Duration> esperas = esperasConfirmacao,
  }) async {
    var resultado = EstadoEntrega.semResposta;
    for (var i = 0; i < esperas.length; i++) {
      if (esperas[i] > Duration.zero) {
        await Future<void>.delayed(esperas[i]);
      }
      final estado = await verificarEntrega(webhookUrl, authHash);
      if (estado == EstadoEntrega.entregue) return estado;
      if (estado == EstadoEntrega.semSuporte) return estado;
      if (estado == EstadoEntrega.semResposta && i == 0) return estado;
      if (estado == EstadoEntrega.naoEncontrado) resultado = estado;
    }
    return resultado;
  }

  /// Motivo da pendência quando o envio não pôde ser confirmado.
  ///
  /// A regra que importa: se a consulta chegou ao Google, havia internet — e o
  /// motivo nunca é [MotivoPendencia.semConexao].
  static String motivoAposFalha({
    required bool foiTimeout,
    required EstadoEntrega consulta,
  }) {
    return switch (consulta) {
      EstadoEntrega.entregue || EstadoEntrega.naoEncontrado =>
        MotivoPendencia.naoConfirmado,
      EstadoEntrega.semSuporte =>
        foiTimeout ? MotivoPendencia.servidorDemorou : MotivoPendencia.naoConfirmado,
      EstadoEntrega.semResposta =>
        foiTimeout ? MotivoPendencia.servidorDemorou : MotivoPendencia.semConexao,
    };
  }

  /// Executa o envio HTTP POST (timeout de 35s) e segue o redirecionamento do
  /// Apps Script via GET para ler a resposta final do script.
  ///
  /// [confirmacaoPerdida]: no celular (Android/iOS) o `dart:io` só segue
  /// redirect sozinho em GET, então o 302 do POST é seguido à mão. O 302 prova
  /// que o doPost rodou, não que gravou. Se esse GET falhar, antes o envio era
  /// dado como entregue sem saber; agora quem decide é a consulta de entrega.
  /// No PWA é o navegador que segue o redirect, e uma falha ali chega como
  /// exceção.
  static Future<({http.Response response, bool confirmacaoPerdida})> _executarPostWebhook(
    String url,
    String bodyJson,
  ) async {
    http.Response response = await _client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: bodyJson,
        )
        .timeout(const Duration(seconds: 35));

    var confirmacaoPerdida = false;
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null && location.trim().isNotEmpty) {
        try {
          response = await _client
              .get(Uri.parse(location))
              .timeout(const Duration(seconds: 20));
        } catch (e) {
          confirmacaoPerdida = true;
          if (kDebugMode) {
            print('[DriveService] Resposta final do Apps Script perdida: $e');
          }
        }
      }
    }

    return (response: response, confirmacaoPerdida: confirmacaoPerdida);
  }

  /// Envia o arquivo PDF (em bytes) para o Google Drive do Gerente via Webhook
  ///
  /// [aoConfirmarEntrega] é chamado se o envio terminar sem confirmação e o app
  /// passar a consultar o Google — para a tela avisar o que está acontecendo.
  static Future<({bool sucesso, String mensagem})> enviarPdfDrive({
    required Uint8List pdfBytes,
    required String nomeArquivo,
    required int turnoId,
    required String operador,
    int? turnoNumero,
    String? authHash,
    VoidCallback? aoConfirmarEntrega,
  }) async {
    final db = DatabaseService.instance;
    final numeroTurnoExibicao = turnoNumero ?? turnoId;
    final isTeste = await isModoTeste();
    final folderId = isTeste ? pastaTestesId : pastaOficialId;

    // No modo teste, prefixa o nome do arquivo com [TESTE]
    final nomeEnvio = isTeste
        ? (nomeArquivo.startsWith('[TESTE]') ? nomeArquivo : '[TESTE] $nomeArquivo')
        : nomeArquivo.replaceFirst(RegExp(r'^\[TESTE\]\s*'), '');

    var webhookUrl = defaultWebhookUrl;
    var foiTimeout = false;

    try {
      webhookUrl = await db.getConfig('google_drive_webhook_url', padrao: defaultWebhookUrl);

      if (webhookUrl.isEmpty) {
        await db.removerPendenciaDrive(turnoId);
        await NotificationService.atualizarPendencias();
        return (
          sucesso: true,
          mensagem: 'PDF salvo localmente (Drive não configurado)'
        );
      }

      final payload = {
        'nome_arquivo': nomeEnvio,
        'turno_id': turnoId,
        // Identifica o FECHAMENTO, não só o turno. O webhook usa isso para
        // escolher o NOME ("(reenvio)" em vez de "_v2") e para responder à
        // consulta de entrega. Nada é substituído nem apagado.
        'auth_hash': authHash ?? '',
        'operador': operador,
        'arquivo_base64': base64Encode(pdfBytes),
        'folderId': folderId,
        'folder_id': folderId,
        'pasta_id': folderId,
        'pastaId': folderId,
        'modo_teste': isTeste,
      };

      final envio = await _executarPostWebhook(webhookUrl, jsonEncode(payload));
      final response = envio.response;

      if (isRespostaSucesso(response)) {
        if (!envio.confirmacaoPerdida) {
          // Envio confirmado: remove pendência e limpa banners
          await db.removerPendenciaDrive(turnoId);
          await NotificationService.atualizarPendencias();
          return (
            sucesso: true,
            mensagem: isTeste
                ? '✅ PDF de teste enviado para a pasta de Testes!'
                : '✅ Fechamento enviado com sucesso!'
          );
        }
        // Script rodou (302), mas a resposta que diria se gravou se perdeu:
        // cai na confirmação abaixo, fora do try.
      } else {
        // Falha real no servidor (4xx ou 5xx): salva na fila offline e notifica
        final pareceLogin = _pareceTelaDeLogin(response.body);
        final motivo = pareceLogin
            ? MotivoPendencia.precisaLogin
            : MotivoPendencia.erroServidor;
        await db.salvarPendenciaDrive(turnoId, nomeEnvio, operador, motivo: motivo);
        await NotificationService.atualizarPendencias();
        NotificationService.notificarPendenciaDrive(
          turnoNumero: numeroTurnoExibicao,
          operador: operador,
          motivo: motivo,
        );
        return (
          sucesso: false,
          mensagem: pareceLogin
              ? 'O Google pediu login em vez de executar o script. Publique o Apps '
                  'Script com acesso "Qualquer pessoa". PDF salvo na fila offline.'
              : 'Servidor retornou código ${response.statusCode}. Salvo na fila offline.'
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DriveService] Erro no envio: $e');
      }
      // Timeout não é o mesmo que estar sem rede: o pedido pode ter chegado e
      // sido processado, e só a resposta ter se perdido.
      foiTimeout = e is TimeoutException;
    }

    // Chegar aqui é não saber se o PDF chegou. Em vez de chutar, pergunta.
    return _resolverEnvioSemConfirmacao(
      webhookUrl: webhookUrl,
      authHash: authHash,
      foiTimeout: foiTimeout,
      turnoId: turnoId,
      nomeEnvio: nomeEnvio,
      operador: operador,
      numeroTurnoExibicao: numeroTurnoExibicao,
      isTeste: isTeste,
      aoConfirmarEntrega: aoConfirmarEntrega,
    );
  }

  static Future<({bool sucesso, String mensagem})> _resolverEnvioSemConfirmacao({
    required String webhookUrl,
    required String? authHash,
    required bool foiTimeout,
    required int turnoId,
    required String nomeEnvio,
    required String operador,
    required int numeroTurnoExibicao,
    required bool isTeste,
    VoidCallback? aoConfirmarEntrega,
  }) async {
    final db = DatabaseService.instance;

    var consulta = EstadoEntrega.semResposta;
    final hash = authHash ?? '';
    if (webhookUrl.isNotEmpty && hash.isNotEmpty) {
      aoConfirmarEntrega?.call();
      consulta = await confirmarEntrega(webhookUrl, hash);
    }

    if (consulta == EstadoEntrega.entregue) {
      await db.removerPendenciaDrive(turnoId);
      await NotificationService.atualizarPendencias();
      return (
        sucesso: true,
        mensagem: isTeste
            ? '✅ PDF de teste confirmado na pasta de Testes!'
            : '✅ Fechamento confirmado no Google Drive!'
      );
    }

    final motivo = motivoAposFalha(foiTimeout: foiTimeout, consulta: consulta);
    await db.salvarPendenciaDrive(turnoId, nomeEnvio, operador, motivo: motivo);
    await NotificationService.atualizarPendencias();
    NotificationService.notificarPendenciaDrive(
      turnoNumero: numeroTurnoExibicao,
      operador: operador,
      motivo: motivo,
    );
    return (sucesso: false, mensagem: MotivoPendencia.descricao(motivo));
  }

  static bool _sincronizando = false;

  /// Sincroniza as pendências da fila offline do Google Drive.
  ///
  /// Com [respeitarBackoff] só entram na rodada as pendências cuja janela de
  /// espera já venceu — é o modo das tentativas automáticas, para não martelar
  /// um webhook fora do ar. O botão "Reenviar" da tela chama sem backoff:
  /// quando o operador pede, a tentativa é imediata.
  ///
  /// Antes de reenviar, cada pendência pergunta ao Google se já chegou: é o que
  /// evita a cópia "(reenvio)" quando só a resposta do envio original se perdeu.
  static Future<({int enviados, int total, bool todosOk, String mensagem})> sincronizarTodasPendencias({
    bool respeitarBackoff = false,
  }) async {
    if (_sincronizando) {
      return (
        enviados: 0,
        total: 0,
        todosOk: true,
        mensagem: 'Sincronização em andamento...'
      );
    }
    _sincronizando = true;
    try {
      final db = DatabaseService.instance;

      // O fechamento que está sendo enviado agora não é assunto da fila: mexer
      // nele criaria um segundo envio do mesmo PDF em paralelo.
      bool foraDoEnvioEmCurso(Map<String, dynamic> p) =>
          !DatabaseService.enviosDriveEmCurso.contains(p['turno_id']);

      final naFila = (await db.obterPendenciasDrive()).where(foraDoEnvioEmCurso).toList();

      if (naFila.isEmpty) {
        await NotificationService.atualizarPendencias();
        return (
          enviados: 0,
          total: 0,
          todosOk: true,
          mensagem: 'Nenhum PDF pendente. Tudo sincronizado no Google Drive! ✅'
        );
      }

      final pendencias = respeitarBackoff
          ? (await db.obterPendenciasDriveVencidas()).where(foraDoEnvioEmCurso).toList()
          : naFila;

      if (pendencias.isEmpty) {
        return (
          enviados: 0,
          total: naFila.length,
          todosOk: false,
          mensagem: 'Aguardando a próxima tentativa automática de envio ao Drive.'
        );
      }

      final webhookUrl = await db.getConfig('google_drive_webhook_url', padrao: defaultWebhookUrl);
      if (webhookUrl.isEmpty) {
        return (
          enviados: 0,
          total: pendencias.length,
          todosOk: false,
          mensagem: 'URL do Google Drive não configurada.'
        );
      }

      int sucessos = 0;
      int aguardandoFechamento = 0;
      for (final p in pendencias) {
        final turnoId = p['turno_id'] as int;
        final operador = (p['operador'] as String?) ?? 'Operador';
        // Nome já gravado na fila, usado se a falha acontecer antes de o nome
        // definitivo ser recalculado a partir do turno.
        var nomeArquivo = (p['caminho_pdf'] as String?) ?? '';

        try {
          final turno = await db.obterTurnoPorId(turnoId);
          if (turno == null) {
            await db.removerPendenciaDrive(turnoId);
            continue;
          }

          // Turno reaberto: o PDF sairia com o turno no meio da edição e com a
          // chave do fechamento anterior — chegaria como "(reenvio)" de algo
          // que mudou. Ele é enviado quando o turno for fechado de novo, e esse
          // fechamento substitui esta pendência.
          if (turno.aberto) {
            aguardandoFechamento++;
            continue;
          }

          final authHash = turno.authHash ?? '';

          // Já chegou? Então só limpa a fila — sem reenviar e sem montar o PDF à
          // toa, o que também poupa o celular.
          if (authHash.isNotEmpty &&
              await verificarEntrega(webhookUrl, authHash) == EstadoEntrega.entregue) {
            await db.removerPendenciaDrive(turnoId);
            sucessos++;
            continue;
          }

          final isTeste = await isModoTeste();
          final folderId = isTeste ? pastaTestesId : pastaOficialId;

          // Montagem do PDF separada do envio: se falhar aqui nada foi à rede,
          // e o motivo não pode ser "sem internet".
          late final List<int> pdfBytes;
          try {
            final totais = await db.obterTotaisTurno(turnoId);
            final lancamentos = await db.obterLancamentos(turnoId);
            await pdf_service.loadLibrary();
            final nomeBase = pdf_service.PdfService.gerarNomeArquivo(turno: turno);
            nomeArquivo = isTeste
                ? (nomeBase.startsWith('[TESTE]') ? nomeBase : '[TESTE] $nomeBase')
                : nomeBase.replaceFirst(RegExp(r'^\[TESTE\]\s*'), '');
            pdfBytes = await pdf_service.PdfService.gerarPdfFechamento(
              turno: turno,
              totais: totais,
              lancamentos: lancamentos,
            );
          } catch (e) {
            if (kDebugMode) {
              print('[DriveService] PDF do turno $turnoId não montou: $e');
            }
            await db.salvarPendenciaDrive(
              turnoId,
              nomeArquivo,
              operador,
              motivo: MotivoPendencia.erroApp,
            );
            continue;
          }

          final payload = {
            'nome_arquivo': nomeArquivo,
            'turno_id': turnoId,
            // Mesmo fechamento da tentativa original: o hash vem gravado no
            // turno, então o webhook reconhece o reenvio e nomeia o arquivo
            // como "... (reenvio).pdf". O PDF nunca deixa de ser gravado: na
            // dúvida o script cria uma cópia a mais, nunca uma a menos.
            'auth_hash': authHash,
            'operador': operador,
            'arquivo_base64': base64Encode(pdfBytes),
            'folderId': folderId,
            'folder_id': folderId,
            'pasta_id': folderId,
            'pastaId': folderId,
            'modo_teste': isTeste,
          };

          var semConfirmacao = false;
          var foiTimeout = false;
          try {
            final envio = await _executarPostWebhook(webhookUrl, jsonEncode(payload));
            if (isRespostaSucesso(envio.response)) {
              if (!envio.confirmacaoPerdida) {
                await db.removerPendenciaDrive(turnoId);
                sucessos++;
                continue;
              }
              semConfirmacao = true;
            } else {
              // Regrava a pendência para incrementar o contador de tentativas e
              // empurrar a próxima tentativa automática para mais longe.
              await db.salvarPendenciaDrive(
                turnoId,
                nomeArquivo,
                operador,
                motivo: _pareceTelaDeLogin(envio.response.body)
                    ? MotivoPendencia.precisaLogin
                    : MotivoPendencia.erroServidor,
              );
              continue;
            }
          } catch (e) {
            if (kDebugMode) {
              print('[DriveService] Erro ao sincronizar turno $turnoId: $e');
            }
            semConfirmacao = true;
            foiTimeout = e is TimeoutException;
          }

          if (semConfirmacao) {
            // Uma consulta só, sem esperar: a fila roda de novo sozinha, e a
            // próxima rodada pergunta outra vez antes de reenviar.
            final consulta = authHash.isNotEmpty
                ? await verificarEntrega(webhookUrl, authHash)
                : EstadoEntrega.semResposta;
            if (consulta == EstadoEntrega.entregue) {
              await db.removerPendenciaDrive(turnoId);
              sucessos++;
            } else {
              await db.salvarPendenciaDrive(
                turnoId,
                nomeArquivo,
                operador,
                motivo: motivoAposFalha(foiTimeout: foiTimeout, consulta: consulta),
              );
            }
          }
        } catch (e) {
          // Falha fora da rede e fora da montagem do PDF: o banco local
          if (kDebugMode) {
            print('[DriveService] Pendência do turno $turnoId não processada: $e');
          }
          try {
            await db.salvarPendenciaDrive(
              turnoId,
              nomeArquivo,
              operador,
              motivo: MotivoPendencia.erroApp,
            );
          } catch (_) {}
        }
      }

      await NotificationService.atualizarPendencias();

      if (sucessos > 0) {
        NotificationService.notificarSucessoDrive(totalEnviados: sucessos);
      }

      final total = pendencias.length;
      final todosOk = sucessos == total && sucessos == naFila.length;

      final msg = todosOk
          ? 'Todos os $sucessos relatórios foram enviados com sucesso para o Drive! 🚀'
          : (sucessos > 0
              ? '$sucessos de $total relatórios enviados. Restam ${total - sucessos} pendentes.'
              : 'Nenhum relatório pôde ser entregue agora. O envio automático continua tentando.');
      final avisoReaberto = aguardandoFechamento > 0
          ? ' O PDF de turno reaberto é enviado quando o turno for fechado de novo.'
          : '';

      return (
        enviados: sucessos,
        total: total,
        todosOk: todosOk,
        mensagem: '$msg$avisoReaberto',
      );
    } finally {
      _sincronizando = false;
    }
  }

  /// Verifica a quantidade de pendências na fila
  static Future<int> sincronizarPendencias() async {
    final res = await sincronizarTodasPendencias();
    return res.total - res.enviados;
  }
}
