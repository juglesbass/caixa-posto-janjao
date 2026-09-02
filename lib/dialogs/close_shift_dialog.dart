import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

typedef DadosFechamentoTurno = ({
  double vendasSistema,
  String observacao,
  String authHash,
  String fechadoEm,
});

class CloseShiftDialog extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final ValueChanged<DadosFechamentoTurno> onConfirmarFechamento;

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
  final _controllerPin = TextEditingController();

  double _vendasSistema = 0.0;
  String? _erroPin;
  bool _validando = false;

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
    _controllerPin.dispose();
    super.dispose();
  }

  void _validarEEncerrar() async {
    if (_validando) return;

    final pin = _controllerPin.text.trim();
    if (pin.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _erroPin = 'Informe o PIN para fechar o caixa');
      return;
    }

    setState(() {
      _validando = true;
      _erroPin = null;
    });

    final valido = await AuthService.validarPin(widget.turno.operador, pin);
    if (!valido) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _validando = false;
          _erroPin = 'PIN Incorreto! Fechamento recusado.';
        });
        _controllerPin.clear();
      }
      return;
    }

    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final fechadoEm = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final authHash = AuthService.gerarChaveAutenticacao(
      operador: widget.turno.operador,
      turnoId: widget.turno.id ?? 1,
      totalVendas: widget.totais.totalGeral,
      timestamp: fechadoEm,
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onConfirmarFechamento((
        vendasSistema: _vendasSistema,
        observacao: _controllerObs.text.trim(),
        authHash: authHash,
        fechadoEm: fechadoEm,
      ));
    }
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
            child: const Icon(Icons.verified_user_rounded, color: AppColors.accentLight, size: 22),
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
                  labelText: 'Observação / Justificativa (Opcional)',
                  hintText: 'Ex: Troca de turno, divergência...',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Autenticação Obrigatória via PIN Individual ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  border: Border.all(
                    color: _erroPin != null
                        ? AppColors.red
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: _erroPin != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Autenticação: ${widget.turno.operador}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textPri,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Digite seu PIN individual para assinar digitalmente:',
                      style: TextStyle(fontSize: 11, color: textSec),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controllerPin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 10,
                        fontWeight: FontWeight.bold,
                        color: textPri,
                      ),
                      decoration: InputDecoration(
                        hintText: 'PIN',
                        counterText: '',
                        hintStyle: TextStyle(letterSpacing: 2, fontSize: 13, color: textSec.withOpacity(0.5)),
                        errorText: _erroPin,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      onChanged: (_) {
                        if (_erroPin != null) setState(() => _erroPin = null);
                      },
                      onSubmitted: (_) => _validarEEncerrar(),
                    ),
                  ],
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
          onPressed: _validando ? null : _validarEEncerrar,
          icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
          label: Text(
            _validando ? 'Autenticando...' : 'Autenticar e Fechar',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
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

