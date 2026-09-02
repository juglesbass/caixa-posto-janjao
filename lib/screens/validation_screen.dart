import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';

/// Tela publica de validacao de autenticidade de fechamento de turno.
/// Aberta instantaneamente quando qualquer pessoa escaneia o QR Code do PDF.
class ValidationScreen extends StatelessWidget {
  final String authHash;
  final String operador;
  final String turno;
  final String totalVendas;
  final String dataHora;
  final VoidCallback onAcessarSistema;

  const ValidationScreen({
    super.key,
    required this.authHash,
    required this.operador,
    required this.turno,
    required this.totalVendas,
    required this.dataHora,
    required this.onAcessarSistema,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double? totalNum = double.tryParse(totalVendas);
    final String totalFormatado = totalNum != null
        ? CurrencyFormatter.formatar(totalNum)
        : 'R\$ $totalVendas';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08090F) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CABECALHO COM LOGO POSTO JANJAO
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'POSTO JANJAO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // CARD PRINCIPAL DE AUTENTICIDADE
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111420) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10B981),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'DOCUMENTO AUTENTICO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fechamento de Caixa Certificado Digitalmente',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Faixa de Chave SHA-256
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF181D2E) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.shield_rounded, color: Color(0xFF0284C7), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CHAVE DE AUTENTICACAO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0284C7),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    SelectableText(
                                      authHash,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (ctx) => IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                                  tooltip: 'Copiar Chave',
                                  onPressed: () {
                                    AppHaptics.light();
                                    Clipboard.setData(ClipboardData(text: authHash));
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Chave copiada para a area de transferencia!'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tabela com Detalhes do Turno
                        _itemDetalhe(
                          context,
                          icone: Icons.person_rounded,
                          rotulo: 'Operador Responsavel',
                          valor: operador.isNotEmpty ? operador : 'Nao informado',
                          isDark: isDark,
                        ),
                        const Divider(height: 16),
                        _itemDetalhe(
                          context,
                          icone: Icons.confirmation_number_rounded,
                          rotulo: 'Numero do Turno',
                          valor: turno.isNotEmpty ? 'Turno #$turno' : 'Turno Registrado',
                          isDark: isDark,
                        ),
                        const Divider(height: 16),
                        _itemDetalhe(
                          context,
                          icone: Icons.payments_rounded,
                          rotulo: 'Total de Vendas Pista',
                          valor: totalFormatado,
                          valorColor: const Color(0xFF10B981),
                          isDark: isDark,
                          destaque: true,
                        ),
                        const Divider(height: 16),
                        _itemDetalhe(
                          context,
                          icone: Icons.schedule_rounded,
                          rotulo: 'Data / Horario Fechamento',
                          valor: dataHora.isNotEmpty ? dataHora : 'Registrado no Fechamento',
                          isDark: isDark,
                        ),
                        const Divider(height: 16),
                        _itemDetalhe(
                          context,
                          icone: Icons.lock_rounded,
                          rotulo: 'Metodo de Validacao',
                          valor: 'Homologado via PIN Individual',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // BOTAO DE ENTRAR NO SISTEMA
                  ElevatedButton.icon(
                    onPressed: () {
                      AppHaptics.light();
                      onAcessarSistema();
                    },
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text(
                      'ACESSAR SISTEMA DO POSTO JANJAO',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Posto Janjao Ltda. - Sistema de Gestao Financeira',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextTer : AppColors.lightTextTer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _itemDetalhe(
    BuildContext context, {
    required IconData icone,
    required String rotulo,
    required String valor,
    Color? valorColor,
    required bool isDark,
    bool destaque = false,
  }) {
    return Row(
      children: [
        Icon(
          icone,
          size: 18,
          color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
        ),
        const SizedBox(width: 10),
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
          ),
        ),
        const Spacer(),
        Text(
          valor,
          style: TextStyle(
            fontSize: destaque ? 14.5 : 13,
            fontWeight: destaque ? FontWeight.w900 : FontWeight.w700,
            color: valorColor ?? (isDark ? AppColors.darkTextPri : AppColors.lightTextPri),
          ),
        ),
      ],
    );
  }
}
