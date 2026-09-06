import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'pdf_service.dart';

class DriveService {
  static final http.Client _client = http.Client();

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

  /// Avalia de forma definitiva se a resposta HTTP do upload representa sucesso real.
  /// Suporta códigos 2xx (200 OK, 201 Created, 204 No Content),
  /// códigos 3xx (301, 302, 303, 307, 308 de redirecionamento do Google Apps Script),
  /// e verificação de confirmação textual/JSON no corpo da resposta.
  static bool isRespostaSucesso(http.Response response) {
    final status = response.statusCode;

    // 1. Respostas HTTP 2xx (Sucesso explícito)
    if (status >= 200 && status < 300) {
      // Se houver corpo em JSON, certifica-se de que não é uma mensagem de erro explícita do Apps Script
      try {
        final bodyTrim = response.body.trim();
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
        // Se não for JSON (ex: texto simples ou resposta vazia), 2xx é sucesso absoluto
      }
      return true;
    }

    // 2. Respostas HTTP 3xx (Redirecionamentos típicos do Google Apps Script)
    // O Apps Script executa a função doPost() e salva o arquivo no Google Drive ANTES
    // de retornar o redirecionamento 302 com o cabeçalho 'Location'. Portanto, se o
    // servidor respondeu 302/303/307, o arquivo já foi entregue com sucesso no Drive.
    if (status >= 300 && status < 400) {
      return true;
    }

    // 3. Fallback de verificação de palavras-chave no corpo
    final bodyLower = response.body.toLowerCase();
    if (bodyLower.contains('success') ||
        bodyLower.contains('"status":"ok"') ||
        bodyLower.contains('sucesso')) {
      return true;
    }

    return false;
  }

  /// Executa o envio HTTP POST com suporte resiliente a redes móveis (timeout de 35s)
  /// e acompanhamento automático de redirecionamento 302/303/307 do Apps Script via GET.
  static Future<http.Response> _executarPostWebhook(String url, String bodyJson) async {
    http.Response response = await _client
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: bodyJson,
        )
        .timeout(const Duration(seconds: 35));

    // Se o Apps Script respondeu com redirecionamento, segue via GET para validar a resposta final
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null && location.trim().isNotEmpty) {
        try {
          final redirectResponse = await _client
              .get(Uri.parse(location))
              .timeout(const Duration(seconds: 20));
          response = redirectResponse;
        } catch (e) {
          // Mesmo se o GET de confirmação do redirect der timeout em rede móvel lenta,
          // o POST original já foi recebido e o PDF já foi gravado no Google Drive.
          if (kDebugMode) {
            print('[DriveService] Aviso ao seguir redirect do Apps Script: $e (upload já concluído)');
          }
        }
      }
    }

    return response;
  }

  /// Envia o arquivo PDF (em bytes) para o Google Drive do Gerente via Webhook
  static Future<({bool sucesso, String mensagem})> enviarPdfDrive({
    required Uint8List pdfBytes,
    required String nomeArquivo,
    required int turnoId,
    required String operador,
    int? turnoNumero,
  }) async {
    final db = DatabaseService.instance;
    final numeroTurnoExibicao = turnoNumero ?? turnoId;
    final isTeste = await isModoTeste();
    final folderId = isTeste ? pastaTestesId : pastaOficialId;

    try {
      final webhookUrl = await db.getConfig('google_drive_webhook_url', padrao: defaultWebhookUrl);

      if (webhookUrl.isEmpty) {
        await db.removerPendenciaDrive(turnoId);
        await NotificationService.atualizarPendencias();
        return (
          sucesso: true,
          mensagem: 'PDF salvo localmente (Drive não configurado)'
        );
      }

      // No modo teste, prefixa o nome do arquivo com [TESTE]
      final nomeEnvio = isTeste
          ? (nomeArquivo.startsWith('[TESTE]') ? nomeArquivo : '[TESTE] $nomeArquivo')
          : nomeArquivo.replaceFirst(RegExp(r'^\[TESTE\]\s*'), '');

      final payload = {
        'nome_arquivo': nomeEnvio,
        'turno_id': turnoId,
        'operador': operador,
        'arquivo_base64': base64Encode(pdfBytes),
        'folderId': folderId,
        'folder_id': folderId,
        'pasta_id': folderId,
        'pastaId': folderId,
        'modo_teste': isTeste,
      };

      final bodyJson = jsonEncode(payload);

      // Executa o envio HTTP POST direto com timeout ampliado e suporte a redirects
      final response = await _executarPostWebhook(webhookUrl, bodyJson);

      final bool ok = isRespostaSucesso(response);

      if (ok) {
        // Envio confirmado com sucesso absoluto: remove pendência e limpa banners
        await db.removerPendenciaDrive(turnoId);
        await NotificationService.atualizarPendencias();
        return (
          sucesso: true,
          mensagem: isTeste
              ? '✅ PDF de teste enviado para a pasta de Testes!'
              : '✅ Fechamento enviado com sucesso!'
        );
      } else {
        // Falha real no servidor (4xx ou 5xx): salva na fila offline e notifica
        await db.salvarPendenciaDrive(turnoId, nomeEnvio, operador);
        await NotificationService.atualizarPendencias();
        NotificationService.notificarPendenciaDrive(
          turnoNumero: numeroTurnoExibicao,
          operador: operador,
        );
        return (
          sucesso: false,
          mensagem: 'Servidor retornou código ${response.statusCode}. Salvo na fila offline.'
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DriveService] Erro no envio: $e');
      }
      // Falha de conexão real: salva na fila offline e notifica
      final nomeEnvio = isTeste && !nomeArquivo.startsWith('[TESTE]')
          ? '[TESTE] $nomeArquivo'
          : nomeArquivo;
      await db.salvarPendenciaDrive(turnoId, nomeEnvio, operador);
      await NotificationService.atualizarPendencias();
      NotificationService.notificarPendenciaDrive(
        turnoNumero: numeroTurnoExibicao,
        operador: operador,
      );
      return (
        sucesso: false,
        mensagem: 'Sem conexão com a internet. O PDF foi salvo na fila para envio automático.'
      );
    }
  }

  static bool _sincronizando = false;

  /// Sincroniza todas as pendências da fila offline do Google Drive
  static Future<({int enviados, int total, bool todosOk, String mensagem})> sincronizarTodasPendencias() async {
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
      final pendencias = await db.obterPendenciasDrive();

      if (pendencias.isEmpty) {
        await NotificationService.atualizarPendencias();
        return (
          enviados: 0,
          total: 0,
          todosOk: true,
          mensagem: 'Nenhum PDF pendente. Tudo sincronizado no Google Drive! ✅'
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
      for (final p in pendencias) {
        final turnoId = p['turno_id'] as int;
        final operador = (p['operador'] as String?) ?? 'Operador';

        try {
          final turno = await db.obterTurnoPorId(turnoId);
          if (turno == null) {
            await db.removerPendenciaDrive(turnoId);
            continue;
          }

          final totais = await db.obterTotaisTurno(turnoId);
          final lancamentos = await db.obterLancamentos(turnoId);

          final isTeste = await isModoTeste();
          final folderId = isTeste ? pastaTestesId : pastaOficialId;
          final nomeBase = PdfService.gerarNomeArquivo(turno: turno);
          final nomeArquivo = isTeste
              ? (nomeBase.startsWith('[TESTE]') ? nomeBase : '[TESTE] $nomeBase')
              : nomeBase.replaceFirst(RegExp(r'^\[TESTE\]\s*'), '');
          final pdfBytes = await PdfService.gerarPdfFechamento(
            turno: turno,
            totais: totais,
            lancamentos: lancamentos,
          );

          final payload = {
            'nome_arquivo': nomeArquivo,
            'turno_id': turnoId,
            'operador': operador,
            'arquivo_base64': base64Encode(pdfBytes),
            'folderId': folderId,
            'folder_id': folderId,
            'pasta_id': folderId,
            'pastaId': folderId,
            'modo_teste': isTeste,
          };

          final response = await _executarPostWebhook(
            webhookUrl,
            jsonEncode(payload),
          );

          if (isRespostaSucesso(response)) {
            await db.removerPendenciaDrive(turnoId);
            sucessos++;
          }
        } catch (e) {
          if (kDebugMode) {
            print('[DriveService] Erro ao sincronizar turno $turnoId: $e');
          }
        }
      }

      await NotificationService.atualizarPendencias();

      if (sucessos > 0) {
        NotificationService.notificarSucessoDrive(totalEnviados: sucessos);
      }

      final total = pendencias.length;
      final todosOk = sucessos == total;

      final msg = todosOk
          ? 'Todos os $sucessos relatórios foram enviados com sucesso para o Drive! 🚀'
          : (sucessos > 0
              ? '$sucessos de $total relatórios enviados. Restam ${total - sucessos} pendentes.'
              : 'Ainda sem conexão com a internet. Tente novamente mais tarde.');

      return (
        enviados: sucessos,
        total: total,
        todosOk: todosOk,
        mensagem: msg,
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
