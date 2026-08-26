import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'notification_service.dart';
import 'pdf_service.dart';

class DriveService {
  static final http.Client _client = http.Client();

  static const String defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycbzes0dAFXK3_Us145YsnfKXAI_UzVjMHlVG4uK2-cYkxHy2f5M_VCaLEVEJhWOIvcVITQ/exec';

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

    try {
      final webhookUrl = await db.getConfig('google_drive_webhook_url', padrao: defaultWebhookUrl);

      if (webhookUrl.isEmpty) {
        return (
          sucesso: true,
          mensagem: 'PDF salvo localmente (Drive não configurado)'
        );
      }

      final payload = {
        'nome_arquivo': nomeArquivo,
        'turno_id': turnoId,
        'operador': operador,
        'arquivo_base64': base64Encode(pdfBytes),
      };

      final bodyJson = jsonEncode(payload);

      // Usando text/plain para evitar bloqueio de CORS preflight em navegadores Web (PWA)
      final response = await _client
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 302 ||
          response.statusCode == 0) {
        // Envio confirmado com sucesso: remove qualquer pendência residual
        await db.removerPendenciaDrive(turnoId);
        await NotificationService.atualizarPendencias();
        return (
          sucesso: true,
          mensagem: 'PDF enviado com sucesso para o Google Drive do Gerente!'
        );
      } else {
        // Falha no servidor: salva na fila offline e notifica
        await db.salvarPendenciaDrive(turnoId, nomeArquivo, operador);
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
      await db.salvarPendenciaDrive(turnoId, nomeArquivo, operador);
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

  /// Sincroniza todas as pendências da fila offline do Google Drive
  static Future<({int enviados, int total, bool todosOk, String mensagem})> sincronizarTodasPendencias() async {
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

        final nomeArquivo = PdfService.gerarNomeArquivo(turno: turno);
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
        };

        final response = await http
            .post(
              Uri.parse(webhookUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 302 ||
            response.statusCode == 0) {
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
  }

  /// Verifica a quantidade de pendências na fila
  static Future<int> sincronizarPendencias() async {
    final res = await sincronizarTodasPendencias();
    return res.total - res.enviados;
  }
}
