import 'package:flutter/material.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico de Turnos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Consultar e gerenciar turnos anteriores',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E293B), height: 20),

            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                  : _turnos.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum turno registrado.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
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
                                color: const Color(0xFF1E293B).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: statusAberto ? const Color(0xFF10B981) : const Color(0xFF334155),
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
                                          : const Color(0xFF334155).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${t.numero}',
                                      style: TextStyle(
                                        color: statusAberto ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Abertura: ${t.data}',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                        if (t.fechadoEm != null) ...[
                                          const SizedBox(height: 1),
                                          Text(
                                            'Fechado: ${t.fechadoEm}',
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!statusAberto)
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onReabrirTurno(t);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Reabrir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                  foregroundColor: const Color(0xFF94A3B8),
                  side: const BorderSide(color: Color(0xFF334155)),
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
