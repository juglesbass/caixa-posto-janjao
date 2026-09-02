import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class TurnosAnterioresDialog extends StatefulWidget {
  final Function(Turno turno) onReabrirTurno;

  const TurnosAnterioresDialog({super.key, required this.onReabrirTurno});

  @override
  State<TurnosAnterioresDialog> createState() => _TurnosAnterioresDialogState();
}

class _TurnosAnterioresDialogState extends State<TurnosAnterioresDialog> {
  List<Turno> _turnos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() async {
    setState(() => _carregando = true);
    final db = DatabaseService.instance;
    final lista = await db.obterTodosTurnos();
    if (mounted) {
      setState(() {
        _turnos = lista;
        _carregando = false;
      });
    }
  }

  void _solicitarReabertura(Turno t) async {
    final controller = TextEditingController();
    String? erro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final autorizado = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_open_rounded, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reabrir Turno #${t.numero}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.lightTextPri,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Digite o PIN de ${t.operador} ou da gerência para autorizar a reabertura:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightTextPri,
                ),
                decoration: InputDecoration(
                  labelText: 'PIN de 4 dígitos',
                  counterText: '',
                  prefixIcon: const Icon(Icons.shield_outlined),
                  errorText: erro,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = controller.text.trim();
                final ok = await AuthService.validarPin(t.operador, pin);
                if (ok) {
                  Navigator.of(dialogCtx).pop(true);
                } else {
                  HapticFeedback.heavyImpact();
                  setDlgState(() {
                    erro = 'PIN incorreto. Acesso negado.';
                  });
                  controller.clear();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Autorizar Reabertura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (autorizado == true && mounted) {
      Navigator.of(context).pop();
      widget.onReabrirTurno(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;
    final cardBg = isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Dialog(
      backgroundColor: bgDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, color: Color(0xFF06B6D4), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico de Turnos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                      ),
                      Text(
                        'Consultar e reabrir turnos anteriores',
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSec),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: borderCol, height: 20),

            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                  : _turnos.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum turno registrado.',
                            style: TextStyle(color: textSec),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _turnos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final t = _turnos[index];
                            final statusAberto = t.aberto;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: statusAberto ? const Color(0xFF10B981) : cardBorder,
                                  width: statusAberto ? 1.2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusAberto
                                          ? const Color(0xFF064E3B).withOpacity(0.6)
                                          : (isDark ? const Color(0xFF334155).withOpacity(0.6) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${t.numero}',
                                      style: TextStyle(
                                        color: statusAberto ? const Color(0xFF34D399) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.operador,
                                          style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Abertura: ${t.data}',
                                          style: TextStyle(color: textSec, fontSize: 11),
                                        ),
                                        if (t.fechadoEm != null) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            'Fechado: ${t.fechadoEm}',
                                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 10),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!statusAberto)
                                    ElevatedButton(
                                      onPressed: () => _solicitarReabertura(t),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Reabrir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'EM ANDAMENTO',
                                        style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSec,
                  side: BorderSide(color: borderCol),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
