import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class ResetDialog extends StatelessWidget {
  final VoidCallback onResetConcluido;

  const ResetDialog({super.key, required this.onResetConcluido});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFFCBD5E1) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.pendenciasCount,
      builder: (context, pendentes, _) {
        final temPendencias = pendentes > 0;

        return AlertDialog(
          backgroundColor: bgDialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderCol),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Limpar / Zerar Tudo?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATENÇÃO: Esta ação apagará permanentemente todos os turnos, lançamentos e histórico deste dispositivo.\n\n'
                'Esta operação é irreversível. Deseja realmente zerar todo o banco de dados?',
                style: TextStyle(color: textSec, fontSize: 13, height: 1.4),
              ),
              if (temPendencias) ...[
                const SizedBox(height: 14),
                // Zerar com a fila cheia apagaria fechamentos que nunca chegaram
                // ao Drive do gerente, sem deixar rastro nem como reenviar.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.45) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.red),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLOQUEADO: $pendentes PDF(s) NÃO ENVIADO(S)',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Estes fechamentos ainda não chegaram à pasta do gerente no Google Drive. '
                              'Zerar agora os apagaria para sempre. Envie-os primeiro.',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec)),
            ),
            if (temPendencias)
              ElevatedButton.icon(
                onPressed: () => _enviarPendencias(context),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Enviar ao Drive',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            else
              ElevatedButton(
                onPressed: () => _zerar(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Sim, Zerar Tudo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _zerar(BuildContext context) async {
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
  }
}
