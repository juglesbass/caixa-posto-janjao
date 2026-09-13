import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:caixa_posto_janjao/models/motivo_pendencia.dart';
import 'package:caixa_posto_janjao/services/drive_service.dart';

void main() {
  group('Consulta de entrega - ler a resposta do Apps Script', () {
    test('Fechamento encontrado e não encontrado', () {
      expect(
        DriveService.interpretarVerificacao(
          http.Response('{"status":"ok","verificacao":true,"encontrado":true}', 200),
        ),
        EstadoEntrega.entregue,
      );
      expect(
        DriveService.interpretarVerificacao(
          http.Response('{"status":"ok","verificacao":true,"encontrado":false}', 200),
        ),
        EstadoEntrega.naoEncontrado,
      );
    });

    test('Script antigo, sem a consulta, não é confundido com resposta', () {
      // O health check do script publicado hoje responde 200 com JSON, mas não
      // diz nada sobre o fechamento. Ler isso como "não chegou" faria reenviar.
      const healthCheckAntigo =
          '{"status":"ok","servico":"Caixa Posto Janjao","modo":"append_only","reenvio_rotulado":true}';
      expect(
        DriveService.interpretarVerificacao(http.Response(healthCheckAntigo, 200)),
        EstadoEntrega.semSuporte,
      );
    });

    test('Login, erro e resposta estranha não viram "entregue"', () {
      const login = '<html><title>Sign in - Google Accounts</title>'
          '<form action="https://accounts.google.com/ServiceLogin"></form></html>';
      for (final r in [
        http.Response(login, 200),
        http.Response('Internal Error', 500),
        http.Response('', 200),
        http.Response('{"verificacao":true}', 200),
        http.Response('{"verificacao":"true","encontrado":"true"}', 200),
      ]) {
        expect(DriveService.interpretarVerificacao(r), EstadoEntrega.semSuporte,
            reason: 'corpo: ${r.body} / ${r.statusCode}');
      }
    });

    test('URL da consulta leva o hash codificado', () {
      final uri = DriveService.montarUrlVerificacao(
        'https://script.google.com/macros/s/ABC/exec',
        'AUTH-1A2B-3C4D-5E6F',
      );
      expect(uri.path, '/macros/s/ABC/exec');
      expect(uri.queryParameters['verificar'], 'AUTH-1A2B-3C4D-5E6F');
    });

    test('Sem hash não consulta nada', () async {
      expect(
        await DriveService.verificarEntrega('https://exemplo.invalido/exec', '  '),
        EstadoEntrega.semResposta,
      );
    });
  });

  group('Motivo depois de um envio sem confirmação', () {
    test('Se o Google respondeu, havia internet: nunca "sem conexão"', () {
      for (final foiTimeout in [true, false]) {
        for (final consulta in [EstadoEntrega.naoEncontrado, EstadoEntrega.semSuporte]) {
          expect(
            DriveService.motivoAposFalha(foiTimeout: foiTimeout, consulta: consulta),
            isNot(MotivoPendencia.semConexao),
            reason: 'timeout=$foiTimeout consulta=$consulta',
          );
        }
      }
    });

    test('Fechamento não encontrado com rede boa é "não confirmado"', () {
      expect(
        DriveService.motivoAposFalha(foiTimeout: false, consulta: EstadoEntrega.naoEncontrado),
        MotivoPendencia.naoConfirmado,
      );
      expect(
        DriveService.motivoAposFalha(foiTimeout: true, consulta: EstadoEntrega.naoEncontrado),
        MotivoPendencia.naoConfirmado,
      );
    });

    test('Sem resposta nenhuma: timeout segue "servidor demorou", o resto é falta de rede', () {
      expect(
        DriveService.motivoAposFalha(foiTimeout: true, consulta: EstadoEntrega.semResposta),
        MotivoPendencia.servidorDemorou,
      );
      expect(
        DriveService.motivoAposFalha(foiTimeout: false, consulta: EstadoEntrega.semResposta),
        MotivoPendencia.semConexao,
      );
    });

    test('Esperas da confirmação são curtas para o operador', () {
      final total = DriveService.esperasConfirmacao.fold<Duration>(
        Duration.zero,
        (soma, d) => soma + d,
      );
      expect(DriveService.esperasConfirmacao.first, Duration.zero);
      expect(total, lessThanOrEqualTo(const Duration(seconds: 30)));
    });
  });
}
