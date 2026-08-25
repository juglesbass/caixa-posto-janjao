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
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
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
                      const Text(
                        'Envio Pendente para o Drive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Turno #${widget.turnoNumero} · ${widget.operador}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ O turno foi encerrado e o PDF foi salvo com segurança neste dispositivo.',
                    style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ Porém, devido à falta de conexão com a internet, o relatório ainda não foi entregue no Google Drive do Gerente e está guardado na fila.',
                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12.5),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _sucesso
                            ? const Color(0xFF064E3B).withOpacity(0.6)
                            : const Color(0xFF7F1D1D).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _feedback!,
                        style: TextStyle(
                          color: _sucesso ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_enviando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Tentando conectar e reenviar PDF...',
                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _tentarReenviar,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar Enviar Novamente Agora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Entendido, Enviar Mais Tarde'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
