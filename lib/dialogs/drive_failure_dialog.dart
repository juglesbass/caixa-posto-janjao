import 'package:flutter/material.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';
import '../widgets/janela.dart';

class DriveFailureDialog extends StatefulWidget {
  final int turnoNumero;
  final String operador;
  final String mensagemErro;
  final VoidCallback onSincronizado;

  const DriveFailureDialog({
    super.key,
    required this.turnoNumero,
    required this.operador,
    required this.mensagemErro,
    required this.onSincronizado,
  });

  @override
  State<DriveFailureDialog> createState() => _DriveFailureDialogState();
}

class _DriveFailureDialogState extends State<DriveFailureDialog> {
  bool _enviando = false;
  String? _feedback;
  bool _sucesso = false;

  Future<void> _tentarReenviar() async {
    setState(() {
      _enviando = true;
      _feedback = null;
    });

    final res = await DriveService.sincronizarTodasPendencias();

    if (mounted) {
      setState(() {
        _enviando = false;
        _feedback = res.mensagem;
        _sucesso = res.todosOk;
      });

      if (res.todosOk) {
        widget.onSincronizado();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CabecalhoJanela(
              icone: Icons.cloud_off_rounded,
              cor: AppColors.amber,
              titulo: 'Envio Pendente para o Drive',
              subtitulo: 'Turno #${widget.turnoNumero} · ${widget.operador}',
            ),
            const SizedBox(height: 16),
            const AvisoJanela(
              cor: AppColors.green,
              icone: Icons.check_circle_rounded,
              texto: 'O turno foi encerrado e está guardado com segurança neste dispositivo.',
            ),
            const SizedBox(height: 8),
            // Motivo real do envio. Este texto era fixo em "falta de conexão
            // com a internet" desde 25/08 e aparecia até quando havia sinal e o
            // PDF já estava no Drive.
            AvisoJanela(
              cor: AppColors.amber,
              icone: Icons.warning_amber_rounded,
              texto: widget.mensagemErro,
            ),
            const SizedBox(height: 16),

            if (_feedback != null) ...[
              AvisoJanela(
                cor: _sucesso ? AppColors.green : AppColors.red,
                icone: _sucesso ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                texto: _feedback!,
              ),
              const SizedBox(height: 16),
            ],

            BotaoPrincipal(
              texto: _enviando ? 'Enviando ao Drive...' : 'Tentar Enviar Novamente Agora',
              icone: Icons.sync_rounded,
              ocupado: _enviando,
              onPressed: _enviando ? null : _tentarReenviar,
            ),
            const SizedBox(height: 4),
            BotaoSecundario(
              texto: 'Entendido, Enviar Mais Tarde',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
