import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/app_pronto.dart';
import '../utils/currency_formatter.dart';
import '../widgets/janela.dart';

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
    // Esta rota não passa pelo MainShell, que é quem normalmente avisa. Sem isto
    // o link público de validação ficaria preso no carregador do index.html até
    // a rede de segurança de 8 segundos.
    sinalizarAppPronto();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
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
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'POSTO JANJÃO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: AppTexto.valor,
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
                      decoration: _cartao(isDark, isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: AppColors.accent),
                          const SizedBox(height: 16),
                          Text(
                            'Consultando registros de autenticidade...',
                            style: TextStyle(
                              fontSize: AppTexto.corpo - 1,
                              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                            ),
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
                  BotaoPrincipal(
                    texto: 'Acessar Sistema do Posto Janjão',
                    icone: Icons.dashboard_rounded,
                    onPressed: () {
                      AppHaptics.light();
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Posto Janjão Ltda. · Autenticação Eletrônica Garantida',
                      style: TextStyle(
                        fontSize: AppTexto.rotulo,
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

  /// Moldura dos cartões desta tela: a mesma dos blocos do app, com a borda
  /// na cor do resultado (verde válido, vermelho inválido).
  BoxDecoration _cartao(bool isDark, Color borda) => BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borda),
      );

  Widget _selo(IconData icone, Color cor, bool isDark) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: isDark ? 0.16 : 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icone, color: cor, size: 36),
      );

  Widget _tituloVerificacao(bool isDark) => Text(
        'Posto Janjão - Verificação de Autenticidade',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: AppTexto.corpo - 1,
          color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
        ),
      );

  Widget _construirCardValido(BuildContext context, bool isDark) {
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fio = Divider(color: borderCol, height: 16);

    return Container(
      decoration: _cartao(isDark, AppColors.green.withValues(alpha: 0.45)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        children: [
          _tituloVerificacao(isDark),
          const SizedBox(height: 14),
          _selo(Icons.verified_user_rounded, AppColors.green, isDark),
          const SizedBox(height: 12),
          const Text(
            'Documento Válido e Autenticado no Sistema',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
              fontSize: AppTexto.valor,
            ),
          ),
          const SizedBox(height: 16),

          // Caixa da Chave SHA-256
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : AppColors.lightBg,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                const Icon(Icons.key_rounded, color: AppColors.accentLight, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHAVE DIGITAL',
                        style: TextStyle(
                          fontSize: AppTexto.rotulo - 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textTer,
                        ),
                      ),
                      SelectableText(
                        _authExibicao,
                        style: TextStyle(
                          fontFamily: AppTexto.numeros,
                          fontSize: AppTexto.corpo - 1,
                          fontWeight: FontWeight.w600,
                          color: textPri,
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
          fio,
          _blocoInformacao(
            icone: Icons.person_rounded,
            rotulo: 'Operador Caixa',
            valor: _operadorExibicao,
            isDark: isDark,
          ),
          fio,
          _blocoInformacao(
            icone: Icons.payments_rounded,
            rotulo: 'Total de Vendas',
            valor: _totalVendasExibicao,
            valorColor: AppColors.green,
            isDark: isDark,
            destaque: true,
          ),
          fio,
          _blocoInformacao(
            icone: Icons.schedule_rounded,
            rotulo: 'Data/Hora da Assinatura',
            valor: _dataHoraExibicao,
            isDark: isDark,
          ),
          fio,
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
      decoration: _cartao(isDark, AppColors.red.withValues(alpha: 0.45)),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _tituloVerificacao(isDark),
          const SizedBox(height: 14),
          _selo(Icons.gpp_bad_rounded, AppColors.red, isDark),
          const SizedBox(height: 12),
          const Text(
            'Documento não encontrado ou Chave Inválida',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.red,
              fontWeight: FontWeight.w800,
              fontSize: AppTexto.valor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatoReconhecido
                ? 'Formato de chave reconhecido, porém não foi possível verificar no banco de dados local.'
                : 'A chave informada não pôde ser autenticada nos registros do Posto Janjão. Certifique-se de que o fechamento foi homologado corretamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTexto.corpo - 1,
              height: 1.4,
              color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
            ),
          ),
          const SizedBox(height: 16),

          if (_authExibicao.isNotEmpty)
            AvisoJanela(
              cor: AppColors.red,
              icone: Icons.error_outline_rounded,
              texto: 'Chave consultada: $_authExibicao',
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
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: IconeJanela(icone: icone, cor: AppColors.accentLight, tamanho: 32),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: AppTexto.rotulo,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valor,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: destaque ? AppTexto.valor + 2 : AppTexto.corpo,
                    fontWeight: destaque ? FontWeight.w800 : FontWeight.w700,
                    color: valorColor ?? (isDark ? AppColors.darkTextPri : AppColors.lightTextPri),
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
