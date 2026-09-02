import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
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
      AppHaptics.heavy();
      setState(() => _erroPin = 'Informe o PIN para fechar o caixa');
      return;
    }

    setState(() {
      _validando = true;
      _erroPin = null;
    });

    final valido = await AuthService.validarPin(widget.turno.operador, pin);
    if (!valido) {
      AppHaptics.heavy();
      if (mounted) {
        setState(() {
          _validando = false;
          _erroPin = 'PIN Incorreto! Fechamento recusado.';
        });
        _controllerPin.clear();
      }
      return;
    }

    AppHaptics.medium();
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
      backgroundColor: isDark ? const Color(0xFF0B1120) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fechamento de Caixa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textPri,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Turno #${widget.turno.numero}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${widget.turno.operador}',
                        style: TextStyle(fontSize: 11, color: textSec, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              color: textSec,
              splashRadius: 18,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      content: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Hero KPI Card: Apuração Financeira ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                  boxShadow: [
                    if (isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 5),
                            Text(
                              'TOTAL FÍSICO APURADO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: textSec,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Na Pista',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatar(widget.totais.totalGeral),
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: textPri,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: isDark
                          ? const Color(0xFF334155).withOpacity(0.6)
                          : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Dinheiro Físico',
                                    style: TextStyle(fontSize: 11, color: textSec),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatar(widget.totais.dinheiro),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4ADE80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          color: isDark
                              ? const Color(0xFF334155).withOpacity(0.5)
                              : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF38BDF8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Cartões / Vouchers',
                                    style: TextStyle(fontSize: 11, color: textSec),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatar(widget.totais.cartoes),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textPri,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 2. Campo Vendas Sistema PDV ──
              TextField(
                controller: _controllerVendasSistema,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                scrollPadding: const EdgeInsets.all(80),
                inputFormatters: [CurrencyInputFormatter()],
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPri,
                ),
                decoration: InputDecoration(
                  labelText: 'Vendas Sistema (Relatório PDV)',
                  labelStyle: TextStyle(fontSize: 12.5, color: textSec),
                  hintText: 'R\$ 0,00',
                  prefixIcon: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF38BDF8), size: 19),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.4) : const Color(0xFFF1F5F9),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _vendasSistema = CurrencyFormatter.parse(val);
                  });
                },
              ),
              const SizedBox(height: 10),

              // ── 3. Banner Dinâmico de Conciliação / Auditoria ──
              if (temVendasSistema) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: corAuditoria.withOpacity(isDark ? 0.14 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: corAuditoria.withOpacity(0.5), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: corAuditoria.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconeAuditoria, color: corAuditoria, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tituloAuditoria,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: corAuditoria,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              batido
                                  ? 'Valores conferem perfeitamente (Diferença zero)'
                                  : '${ehSobra ? '+' : ''}${CurrencyFormatter.formatar(diferenca)}',
                              style: TextStyle(
                                fontSize: 14.5,
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
                const SizedBox(height: 10),
              ],

              // ── 4. Assinatura Digital do Operador via PIN ──
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _erroPin != null
                        ? AppColors.red
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                    width: _erroPin != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 15),
                            const SizedBox(width: 5),
                            Text(
                              'Assinatura Digital (PIN)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textPri,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.turno.operador,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: _controllerPin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 4,
                      scrollPadding: const EdgeInsets.all(80),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w900,
                        color: textPri,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: TextStyle(
                          letterSpacing: 8,
                          fontSize: 17,
                          color: textSec.withOpacity(0.35),
                        ),
                        counterText: '',
                        errorText: _erroPin,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
                        ),
                      ),
                      onChanged: (_) {
                        if (_erroPin != null) setState(() => _erroPin = null);
                      },
                      onSubmitted: (_) => _validarEEncerrar(),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_clock_outlined, size: 10, color: textSec),
                        const SizedBox(width: 4),
                        Text(
                          'Autenticação criptográfica SHA-256',
                          style: TextStyle(fontSize: 9.5, color: textSec),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── 5. Campo de Observação (Opcional) ──
              TextField(
                controller: _controllerObs,
                maxLines: 1,
                scrollPadding: const EdgeInsets.all(80),
                style: TextStyle(fontSize: 12.5, color: textPri),
                decoration: InputDecoration(
                  labelText: 'Observação / Justificativa (Opcional)',
                  labelStyle: TextStyle(fontSize: 12, color: textSec),
                  hintText: 'Ex: Troca de turno, divergência...',
                  hintStyle: TextStyle(fontSize: 11.5, color: textSec.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF94A3B8), size: 19),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : const Color(0xFFF1F5F9),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155).withOpacity(0.7) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      actions: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: textSec,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _validando ? null : _validarEEncerrar,
                  icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 17),
                  label: Text(
                    _validando ? 'Autenticando...' : 'Autenticar e Fechar',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

