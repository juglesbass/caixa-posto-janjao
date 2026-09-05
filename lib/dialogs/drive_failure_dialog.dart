import 'package:flutter/material.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;
    final boxBg = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFFEF3C7);
    final boxBorder = isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A);
    final boxText = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
    final boxTextSec = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF78350F);

    return Dialog(
      backgroundColor: bgDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFF59E0B),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Envio Pendente para o Drive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPri,
                        ),
                      ),
                      Text(
                        'Turno #${widget.turnoNumero} · ${widget.operador}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textSec,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card explicativo de pendência
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: boxBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'O turno foi encerrado e o PDF foi salvo com segurança neste dispositivo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: boxTextSec,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Porém, devido à falta de conexão com a internet, o relatório ainda não foi entregue no Google Drive do Gerente e está guardado na fila.',
                          style: TextStyle(
                            fontSize: 12,
                            color: boxText,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_feedback != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _sucesso
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _sucesso ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _sucesso ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      color: _sucesso ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _sucesso ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              onPressed: _enviando ? null : _tentarReenviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
              label: Text(
                _enviando ? 'Enviando ao Drive...' : 'Tentar Enviar Novamente Agora',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),

            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSec,
                side: BorderSide(color: borderCol),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Entendido, Enviar Mais Tarde', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
