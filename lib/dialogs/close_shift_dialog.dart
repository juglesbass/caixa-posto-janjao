import 'package:flutter/material.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class CloseShiftDialog extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final ValueChanged<({double vendasSistema, String observacao})> onConfirmarFechamento;

  const CloseShiftDialog({
    super.key,
    required this.turno,
    required this.totais,
    required this.onConfirmarFechamento,
  });

  @override
  State<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<CloseShiftDialog> {
  late TextEditingController _controllerVendasSistema;
  late TextEditingController _controllerObs;

  double _vendasSistema = 0.0;

  @override
  void initState() {
    super.initState();
    _vendasSistema = widget.turno.vendasSistema;
    _controllerVendasSistema = TextEditingController(
      text: widget.turno.vendasSistema > 0
          ? CurrencyFormatter.formatar(widget.turno.vendasSistema)
          : '',
    );
    _controllerObs = TextEditingController(text: widget.turno.observacao);
  }

  @override
  void dispose() {
    _controllerVendasSistema.dispose();
    _controllerObs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final diferenca = widget.totais.totalGeral - _vendasSistema;
    final bool temVendasSistema = _vendasSistema > 0;
    final bool ehSobra = diferenca > 0.009;
    final bool ehFalta = diferenca < -0.009;
    final bool batido = temVendasSistema && !ehSobra && !ehFalta;

    Color corAuditoria = AppColors.green;
    String tituloAuditoria = 'CAIXA 100% BATIDO';
    IconData iconeAuditoria = Icons.check_circle_rounded;

    if (ehSobra) {
      corAuditoria = AppColors.amber;
      tituloAuditoria = 'SOBRA NA PISTA';
      iconeAuditoria = Icons.trending_up_rounded;
    } else if (ehFalta) {
      corAuditoria = AppColors.red;
      tituloAuditoria = 'FALTA NA PISTA';
      iconeAuditoria = Icons.trending_down_rounded;
    }

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(Icons.lock_clock_rounded, color: AppColors.accentLight, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fechamento de Turno #${widget.turno.numero}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Resumo Geral ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _linhaResumo('Total Físico (Lançamentos):', CurrencyFormatter.formatar(widget.totais.totalGeral), textPri, isBold: true),
                    const SizedBox(height: 4),
                    _linhaResumo('Sobra de Dinheiro:', CurrencyFormatter.formatar(widget.totais.dinheiro), AppColors.green),
                    const SizedBox(height: 4),
                    _linhaResumo('Cartões / Vouchers:', CurrencyFormatter.formatar(widget.totais.cartoes), AppColors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Campo Vendas Sistema PDV ──
              TextField(
                controller: _controllerVendasSistema,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Vendas Sistema (Relatório PDV)',
                  hintText: 'R\$ 0,00',
                  prefixIcon: const Icon(Icons.assessment_outlined),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _vendasSistema = CurrencyFormatter.parse(val);
                  });
                },
              ),
              const SizedBox(height: 12),

              // ── Banner Dinâmico de Auditoria ──
              if (temVendasSistema) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: corAuditoria.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: corAuditoria.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(iconeAuditoria, color: corAuditoria, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tituloAuditoria,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: corAuditoria,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              batido
                                  ? 'Valores conferem perfeitamente!'
                                  : '${ehSobra ? '+' : ''}${CurrencyFormatter.formatar(diferenca)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: corAuditoria,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Campo de Observação ──
              TextField(
                controller: _controllerObs,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Observação / Justificativa',
                  hintText: 'Ex: Troca de turno, divergência...',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: textSec)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirmarFechamento((
              vendasSistema: _vendasSistema,
              observacao: _controllerObs.text.trim(),
            ));
          },
          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
          label: const Text('Encerrar Turno', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
          ),
        ),
      ],
    );
  }

  Widget _linhaResumo(String label, String valor, Color corValor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: corValor,
          ),
        ),
      ],
    );
  }
}
