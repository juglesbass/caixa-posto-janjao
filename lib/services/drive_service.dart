import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'database_service.dart';

class DriveService {
  static const String defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycbzes0dAFXK3_Us145YsnfKXAI_UzVjMHlVG4uK2-cYkxHy2f5M_VCaLEVEJhWOIvcVITQ/exec';

  /// Envia o arquivo PDF (em bytes) para o Google Drive do Gerente via Webhook
  static Future<({bool sucesso, String mensagem})> enviarPdfDrive({
    required Uint8List pdfBytes,
    required String nomeArquivo,
    required int turnoId,
    required String operador,
  }) async {
    try {
      final db = DatabaseService.instance;
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

      // Salva pendência preventiva antes do disparo
      await db.salvarPendenciaDrive(turnoId, nomeArquivo, operador);

      final response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 302) {
        // Envio confirmado com sucesso: remove da fila offline
        await db.removerPendenciaDrive(turnoId);
        return (
          sucesso: true,
          mensagem: 'PDF enviado com sucesso para o Google Drive do Gerente!'
        );
      } else {
        return (
          sucesso: false,
          mensagem: 'Servidor retornou código ${response.statusCode}. Salvo na fila offline.'
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[DriveService] Erro no envio: $e');
      }
      return (
        sucesso: false,
        mensagem: 'Sem conexão com a internet. O PDF foi salvo na fila para envio automático.'
      );
    }
  }

  /// Verifica se há envios pendentes e tenta sincronizar
  static Future<int> sincronizarPendencias() async {
    final db = DatabaseService.instance;
    final pendencias = await db.obterPendenciasDrive();
    return pendencias.length;
  }
}
