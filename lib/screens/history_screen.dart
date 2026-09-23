import 'package:flutter/material.dart';
import '../dialogs/edit_launch_dialog.dart';
import '../models/lancamento.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/cabecalho_turno.dart';
import '../widgets/filtro_pilula.dart';

class HistoryScreen extends StatefulWidget {
  final Turno turno;

  /// Aba visível. Escondida, a tela não relê o turno a cada lançamento feito
  /// no Início — relê ao voltar a ser vista (didUpdateWidget).
  final bool ativo;

  const HistoryScreen({
    super.key,
    required this.turno,
    this.ativo = true,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Lancamento> _lancamentos = [];
  String _filtroTipo = 'Todos';
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
    DatabaseService.lancamentosNotifier.addListener(_onLancamentosMudaram);
  }

  @override
  void dispose() {
    DatabaseService.lancamentosNotifier.removeListener(_onLancamentosMudaram);
    super.dispose();
  }

  void _onLancamentosMudaram() {
    if (mounted && widget.ativo && widget.turno.id != null) {
      _carregar(silencioso: _lancamentos.isNotEmpty);
    }
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turno.id != widget.turno.id || (widget.ativo && !oldWidget.ativo)) {
      _carregar(silencioso: _lancamentos.isNotEmpty);
    }
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso && _lancamentos.isEmpty) {
      setState(() => _carregando = true);
    }
    try {
      final db = DatabaseService.instance;
      final lista = await db.obterLancamentos(widget.turno.id!);
      if (mounted) {
        setState(() {
          _lancamentos = lista;
          _lancamentosFiltradosCache = null;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  List<Lancamento>? _lancamentosFiltradosCache;
  String? _filtroCache;

  List<Lancamento> get _lancamentosFiltrados {
    if (_lancamentosFiltradosCache != null && _filtroCache == _filtroTipo) {
      return _lancamentosFiltradosCache!;
    }
    _filtroCache = _filtroTipo;
    if (_filtroTipo == 'Todos') {
      _lancamentosFiltradosCache = _lancamentos;
    } else if (_filtroTipo == 'Cartões') {
      _lancamentosFiltradosCache = _lancamentos.where((l) => PaymentTypes.ehCartao(l.tipo)).toList();
    } else {
      _lancamentosFiltradosCache = _lancamentos.where((l) => l.tipo.toLowerCase().contains(_filtroTipo.toLowerCase())).toList();
    }
    return _lancamentosFiltradosCache!;
  }

  void _abrirEdicao(Lancamento lancamento) async {
    await showDialog(
      context: context,
      builder: (ctx) => EditLaunchDialog(
        lancamento: lancamento,
        maquinaAtiva: PaymentTypes.maquinaRede,
        onSalvar: (dados) async {
          final db = DatabaseService.instance;
          await db.atualizarLancamento(
            lancamento.id!,
            widget.turno.id!,
            dados.tipo,
            dados.valor,
            dados.descricao,
          );
          // Esta lista e os totais se atualizam pelo aviso do banco
          // (lancamentosNotifier).
        },
        onDeletar: () async {
          final db = DatabaseService.instance;
          await db.deletarLancamento(lancamento.id!, widget.turno.id!);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Sangria saiu do app: o filtro so aparece se este turno tiver alguma
    // sangria antiga para mostrar.
    final temSangria = _lancamentos.any((l) => PaymentTypes.ehSangria(l.tipo));
    final filtros = [
      'Todos', 'Dinheiro', 'Pix', 'Cartões', 'Despesas',
      if (temSangria || _filtroTipo == 'Sangria') 'Sangria',
    ];
    final lista = _lancamentosFiltrados;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Histórico',
                    style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                  ),
                  Text(
                    _lancamentos.length == 1 ? '1 lançamento neste turno' : '${_lancamentos.length} lançamentos neste turno',
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                  ),
                ],
              ),
            ),
            if (widget.turno.isFechado) const SeloTurno(texto: 'Fechado', cor: AppColors.amber),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentLight),
            tooltip: 'Atualizar lista',
            onPressed: _carregar,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Filtros ──
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              children: [
                for (final f in filtros)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FiltroPilula(
                      texto: f,
                      selecionado: _filtroTipo == f,
                      onTap: () => setState(() {
                        _filtroTipo = f;
                        _lancamentosFiltradosCache = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),

          // ── Lista de lançamentos ──
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentLight))
                : lista.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 44, color: textTer),
                            const SizedBox(height: 12),
                            Text(
                              _filtroTipo == 'Todos'
                                  ? 'Nenhum lançamento neste turno ainda.'
                                  : 'Nenhum lançamento em $_filtroTipo.',
                              style: TextStyle(color: textSec, fontSize: AppTexto.corpo),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        color: AppColors.accentLight,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                          itemCount: lista.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final l = lista[index];
                            return _LinhaHistorico(
                              lancamento: l,
                              fechado: widget.turno.isFechado,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textPri: textPri,
                              textSec: textSec,
                              textTer: textTer,
                              onTap: () {
                                if (widget.turno.isFechado) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Turno fechado: os lançamentos não podem mais ser alterados.'),
                                      backgroundColor: AppColors.amber,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                _abrirEdicao(l);
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Um lançamento no Histórico, na mesma linguagem dos últimos lançamentos da
/// tela Início: ícone na cor da forma, valor em cor neutra e com dígitos
/// alinhados. A cor fica só no ícone — no valor ela fazia quase tudo sair em
/// vermelho (Master é vermelho), com cara de erro.
class _LinhaHistorico extends StatelessWidget {
  final Lancamento lancamento;
  final bool fechado;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPri;
  final Color textSec;
  final Color textTer;
  final VoidCallback onTap;

  const _LinhaHistorico({
    required this.lancamento,
    required this.fechado,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPri,
    required this.textSec,
    required this.textTer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = lancamento;
    final cor = AppColors.getCorTipo(l.tipo);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
              ),
              child: Icon(AppIcones.doTipo(l.tipo), color: cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.tipo,
                    style: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w700, color: textPri),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: l.hora,
                          style: TextStyle(fontFamily: AppTexto.numeros, color: textTer),
                        ),
                        if (l.descricao.isNotEmpty) TextSpan(text: '  ·  ${l.descricao}'),
                      ],
                    ),
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.formatar(l.valor),
              style: TextStyle(
                fontFamily: AppTexto.numeros,
                fontSize: AppTexto.valor,
                fontWeight: FontWeight.w600,
                color: textPri,
              ),
            ),
            const SizedBox(width: 8),
            if (fechado)
              const Tooltip(
                message: 'Turno fechado',
                child: Icon(Icons.lock_rounded, size: 16, color: AppColors.amber),
              )
            else
              Icon(Icons.edit_rounded, size: 16, color: textTer),
          ],
        ),
      ),
    );
  }
}
