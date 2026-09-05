import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';

/// Tela pública de conferência e validação de autenticidade do fechamento de turno
/// Acessível via rota web /validar?auth=AUTH-XXXX-XXXX-XXXX
class ValidarScreen extends StatefulWidget {
  final String? authHash;
  final String? operadorFallback;
  final String? turnoFallback;
  final String? totalFallback;
  final String? dataFallback;

  const ValidarScreen({
    super.key,
    this.authHash,
    this.operadorFallback,
    this.turnoFallback,
    this.totalFallback,
    this.dataFallback,
  });

  @override
  State<ValidarScreen> createState() => _ValidarScreenState();
}

class _ValidarScreenState extends State<ValidarScreen> {
  bool _carregando = true;
  bool _encontrado = false;
  bool _formatoReconhecido = false;
  String _authExibicao = '';
  String _operadorExibicao = 'Autenticado via PIN';
  String _turnoExibicao = 'Turno #Oficial';
  String _dataHoraExibicao = 'Registrada no Sistema';
  String _totalVendasExibicao = 'R\$ Homologado';
  String _metodoAssinatura = 'SHA-256 Oficial Posto Janjão';

  @override
  void initState() {
    super.initState();
    _buscarDadosAutenticacao();
  }

  Future<void> _buscarDadosAutenticacao() async {
    setState(() => _carregando = true);

    // 1. Extração resiliente de parâmetros (widget, URL query e hash fragment)
    final queryParams = Uri.base.queryParameters;
    final fragment = Uri.base.fragment;
    Map<String, String> fragmentParams = {};
    if (fragment.contains('?')) {
      final fragmentUri = Uri.parse(fragment.startsWith('/') ? fragment : '/$fragment');
      fragmentParams = fragmentUri.queryParameters;
    }

    String chave = (widget.authHash ?? fragmentParams['auth'] ?? queryParams['auth'] ?? '').trim();

    _authExibicao = chave;

    if (chave.isEmpty) {
      setState(() {
        _encontrado = false;
        _carregando = false;
      });
      return;
    }

    try {
      // 2. Consulta no banco de dados SQLite local
      final db = DatabaseService.instance;
      final Turno? turnoBanco = await db.obterTurnoPorAuthHash(chave);
      if (!mounted) return;

      if (turnoBanco != null) {
        final TotaisTurno totais = await db.obterTotaisTurno(turnoBanco.id!);
        if (!mounted) return;
        setState(() {
          _encontrado = true;
          _turnoExibicao = 'Turno #${turnoBanco.numero}';
          _operadorExibicao = turnoBanco.operador;
          _totalVendasExibicao = CurrencyFormatter.formatar(totais.totalGeral);
          _dataHoraExibicao = turnoBanco.fechadoEm ?? turnoBanco.data;
          _metodoAssinatura = 'SHA-256 Oficial Posto Janjão';
          _carregando = false;
        });
        return;
      }

      // 3. Verificação de integridade da chave oficial SHA-256 (AUTH-XXXX-XXXX-XXXX)
      final formatoOficialValido = RegExp(
        r'^AUTH-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}$',
        caseSensitive: false,
      ).hasMatch(chave);

      setState(() {
        _encontrado = false;
        _formatoReconhecido = formatoOficialValido;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao validar documento: $e');
      if (mounted) {
        setState(() {
          _encontrado = false;
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  // CABEÇALHO POSTO JANJÃO
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
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
                            'POSTO JANJÃO',
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
                  const SizedBox(height: 20),

                  // ESTADO DE CARREGAMENTO
                  if (_carregando)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111420) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: const [
                          CircularProgressIndicator(color: Color(0xFF2563EB)),
                          SizedBox(height: 16),
                          Text(
                            'Consultando registros de autenticidade...',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  // CASO ENCONTRADO / VÁLIDO
                  else if (_encontrado)
                    _construirCardValido(context, isDark)
                  // CASO INVÁLIDO / NÃO ENCONTRADO
                  else
                    _construirCardInvalido(context, isDark),

                  const SizedBox(height: 20),

                  // BOTÃO DE ACESSO AO SISTEMA
                  ElevatedButton.icon(
                    onPressed: () {
                      AppHaptics.light();
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text(
                      'ACESSAR SISTEMA DO POSTO JANJÃO',
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
                      'Posto Janjão Ltda. · Autenticação Eletrônica Garantida',
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

  Widget _construirCardValido(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111420) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          // Cabeçalho da verificação
          Text(
            'Posto Janjão - Verificação de Autenticidade',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
          const SizedBox(height: 14),

          // Ícone de Escudo Verde
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981), width: 2),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF10B981),
              size: 38,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Documento Válido e Autenticado no Sistema',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Caixa da Chave SHA-256
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181D2E) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, color: Color(0xFF0284C7), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHAVE DIGITAL',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SelectableText(
                        _authExibicao,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                  tooltip: 'Copiar Chave',
                  onPressed: () {
                    AppHaptics.light();
                    Clipboard.setData(ClipboardData(text: _authExibicao));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chave copiada com sucesso!'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detalhes do Fechamento (Layout Mobile-First por Bloco)
          _blocoInformacao(
            icone: Icons.confirmation_number_rounded,
            rotulo: 'Turno',
            valor: _turnoExibicao,
            isDark: isDark,
          ),
          Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 16),
          _blocoInformacao(
            icone: Icons.person_rounded,
            rotulo: 'Operador Caixa',
            valor: _operadorExibicao,
            isDark: isDark,
          ),
          Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 16),
          _blocoInformacao(
            icone: Icons.payments_rounded,
            rotulo: 'Total de Vendas',
            valor: _totalVendasExibicao,
            valorColor: const Color(0xFF10B981),
            isDark: isDark,
            destaque: true,
          ),
          Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 16),
          _blocoInformacao(
            icone: Icons.schedule_rounded,
            rotulo: 'Data/Hora da Assinatura',
            valor: _dataHoraExibicao,
            isDark: isDark,
          ),
          Divider(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0), height: 16),
          _blocoInformacao(
            icone: Icons.shield_rounded,
            rotulo: 'Protocolo de Segurança',
            valor: _metodoAssinatura,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _construirCardInvalido(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111420) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Posto Janjão - Verificação de Autenticidade',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
          const SizedBox(height: 14),

          // Ícone de Alerta Vermelho
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFEF4444), width: 2),
            ),
            child: const Icon(
              Icons.gpp_bad_rounded,
              color: Color(0xFFEF4444),
              size: 38,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Documento não encontrado ou Chave Inválida',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatoReconhecido
                ? 'Formato de chave reconhecido, porém não foi possível verificar no banco de dados local.'
                : 'A chave informada não pôde ser autenticada nos registros do Posto Janjão. Certifique-se de que o fechamento foi homologado corretamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
          const SizedBox(height: 16),

          if (_authExibicao.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181D2E) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chave consultada: $_authExibicao',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _blocoInformacao({
    required IconData icone,
    required String rotulo,
    required String valor,
    Color? valorColor,
    required bool isDark,
    bool destaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icone,
              size: 18,
              color: const Color(0xFF0284C7),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: destaque ? 16 : 13.5,
                    fontWeight: destaque ? FontWeight.w900 : FontWeight.w700,
                    color: valorColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
