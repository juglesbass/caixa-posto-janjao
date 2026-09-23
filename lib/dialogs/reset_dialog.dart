import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/janela.dart';

class ResetDialog extends StatelessWidget {
  final VoidCallback onResetConcluido;

  const ResetDialog({super.key, required this.onResetConcluido});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.pendenciasCount,
      builder: (context, pendentes, _) {
        final temPendencias = pendentes > 0;

        return AlertDialog(
          title: const TituloJanela('Limpar / Zerar Tudo?', icone: Icons.warning_amber_rounded, cor: AppColors.red),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextoJanela(
                'ATENÇÃO: Esta ação apagará permanentemente todos os turnos, lançamentos e histórico deste dispositivo.\n\n'
                'Esta operação é irreversível. Deseja realmente zerar todo o banco de dados?',
              ),
              if (temPendencias) ...[
                const SizedBox(height: 14),
                // Zerar com a fila cheia apagaria fechamentos que nunca chegaram
                // ao Drive do gerente, sem deixar rastro nem como reenviar.
                AvisoJanela(
                  cor: AppColors.red,
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Bloqueado: $pendentes PDF(s) não enviado(s)',
                  texto: 'Estes fechamentos ainda não chegaram à pasta do gerente no Google Drive. '
                      'Zerar agora os apagaria para sempre. Envie-os primeiro.',
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            BotoesJanela(
              secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(context).pop()),
              principal: temPendencias
                  ? BotaoPrincipal(
                      texto: 'Enviar ao Drive',
                      icone: Icons.cloud_upload_rounded,
                      cor: AppColors.amber,
                      onPressed: () => _enviarPendencias(context),
                    )
                  : BotaoPrincipal(
                      texto: 'Sim, Zerar Tudo',
                      cor: AppColors.red,
                      onPressed: () => _zerar(context),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarPendencias(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await DriveService.sincronizarTodasPendencias();
    messenger.showSnackBar(
      SnackBar(
        content: Text(res.mensagem),
        backgroundColor: res.todosOk ? AppColors.green : AppColors.amber,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Dois toques em "Sim, Zerar Tudo" rodavam o reset duas vezes, e cada um
  /// fechava uma tela: o segundo fechava também o painel por baixo da janela
  /// e abria a identificação duas vezes.
  static bool _zerando = false;

  Future<void> _zerar(BuildContext context) async {
    if (_zerando) return;
    _zerando = true;
    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      try {
        await DatabaseService.instance.resetarTudo();
      } on StateError catch (e) {
        // Uma pendência pode ter surgido entre a abertura do diálogo e o toque:
        // o banco recusa e a mensagem explica o motivo em vez de zerar assim mesmo.
        await NotificationService.atualizarPendencias();
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      await NotificationService.atualizarPendencias();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('🗑️ Todos os dados foram zerados com sucesso!'),
          backgroundColor: AppColors.red,
        ),
      );
      onResetConcluido();
    } finally {
      _zerando = false;
    }
  }
}
