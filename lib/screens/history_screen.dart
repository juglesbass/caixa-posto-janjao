import 'package:flutter/material.dart';
import '../dialogs/edit_launch_dialog.dart';
import '../models/lancamento.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';

class HistoryScreen extends StatefulWidget {
  final Turno turno;
  final VoidCallback onAtualizado;
  final bool ativo;

  const HistoryScreen({
    super.key,
    required this.turno,
    required this.onAtualizado,
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
    if (mounted && widget.turno.id != null) {
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
          _carregar();
          widget.onAtualizado();
        },
        onDeletar: () async {
          final db = DatabaseService.instance;
          await db.deletarLancamento(lancamento.id!, widget.turno.id!);
          _carregar();
          widget.onAtualizado();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final filtros = ['Todos', 'Dinheiro', 'Pix', 'Cartões', 'Sangria', 'Despesas'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Histórico (${_lancamentos.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.turno.isFechado) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.amber, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 11, color: AppColors.amber),
                    SizedBox(width: 3),
                    Text(
                      'FECHADO',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.amber),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.accentLight),
            tooltip: 'Atualizar Lista',
            onPressed: _carregar,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de Filtros ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: filtros.map((f) {
                final selecionado = _filtroTipo == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selecionado,
                    onSelected: (_) {
                      setState(() {
                        _filtroTipo = f;
                        _lancamentosFiltradosCache = null;
                      });
                    },
                    selectedColor: AppColors.accent.withOpacity(0.2),
                    checkmarkColor: AppColors.accentLight,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                      color: selecionado ? AppColors.accentLight : textSec,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, color: borderColor),

          // ── Lista de Lançamentos com RefreshIndicator ──
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentLight))
                : _lancamentosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: textSec.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum lançamento encontrado neste turno.',
                              style: TextStyle(color: textSec, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        color: AppColors.accentLight,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _lancamentosFiltrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final l = _lancamentosFiltrados[index];
                            final cor = AppColors.getCorTipo(l.tipo);
                            final icone = AppColors.getIconeTipo(l.tipo);

                            return InkWell(
                              onTap: () {
                                if (widget.turno.isFechado) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🔒 Turno fechado e homologado! Lançamentos bloqueados contra alteração.'),
                                      backgroundColor: AppColors.amber,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                _abrirEdicao(l);
                              },
                              borderRadius: BorderRadius.circular(AppColors.radiusMd),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cor.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                      ),
                                      child: Icon(icone, color: cor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l.tipo,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textPri,
                                            ),
                                          ),
                                          if (l.descricao.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              l.descricao,
                                              style: TextStyle(fontSize: 12, color: textSec),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 2),
                                          Text(
                                            l.hora,
                                            style: TextStyle(fontSize: 11, color: textSec.withOpacity(0.7)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatar(l.valor),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: cor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (widget.turno.isFechado)
                                          const Tooltip(
                                            message: 'Turno Fechado - Bloqueado',
                                            child: Icon(Icons.lock_rounded, size: 14, color: AppColors.amber),
                                          )
                                        else
                                          Icon(Icons.edit_outlined, size: 14, color: textSec.withOpacity(0.5)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
