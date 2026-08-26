import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../dialogs/drive_failure_dialog.dart';
import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/pending_sync_banner.dart';

class SummaryScreen extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final VoidCallback onTurnoAlterado;
  final VoidCallback? onFechar;

  const SummaryScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.onTurnoAlterado,
    this.onFechar,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _vendasSistemaController = TextEditingController();
  final _observacaoController = TextEditingController();

  double _vendasSistema = 0.0;
  String _observacao = '';
  bool _processando = false;
  bool _cartoesExpandidos = false;

  @override
  void initState() {
    super.initState();
    _vendasSistema = widget.turno.vendasSistema;
    _observacao = widget.turno.observacao;

    if (_vendasSistema > 0) {
      _vendasSistemaController.text = CurrencyFormatter.formatar(_vendasSistema);
    }
    _observacaoController.text = _observacao;
  }

  @override
  void didUpdateWidget(covariant SummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turno.id != widget.turno.id || oldWidget.turno.vendasSistema != widget.turno.vendasSistema) {
      _vendasSistema = widget.turno.vendasSistema;
      _observacao = widget.turno.observacao;
      _vendasSistemaController.text = _vendasSistema > 0 ? CurrencyFormatter.formatar(_vendasSistema) : '';
      _observacaoController.text = _observacao;
    }
  }

  @override
  void dispose() {
    _vendasSistemaController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  double get _diferencaAtual => widget.totais.totalGeral - _vendasSistema;

  TotaisTurno get _totaisAtualizados => widget.totais.copyWith(
        vendasSistema: _vendasSistema,
        diferenca: _diferencaAtual,
      );

  Rect _obterOrigemCompartilhamento(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      final pos = box.localToGlobal(Offset.zero);
      return pos & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromLTWH(0, size.height / 2, size.width, 100);
  }

  void _atualizarVendasSistema(String text) {
    final valor = CurrencyFormatter.parse(text);
    setState(() {
      _vendasSistema = valor;
    });
    DatabaseService.instance.salvarAuditoria(widget.turno.id!, _vendasSistema, _observacao);
  }

  void _atualizarObservacao(String text) {
    _observacao = text;
    DatabaseService.instance.salvarAuditoria(widget.turno.id!, _vendasSistema, _observacao);
  }

  String _montarTextoResumo() {
    final buffer = StringBuffer();
    buffer.writeln('⛽ *POSTO JANJÃO - FECHAMENTO DE TURNO*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('👤 *Operador:* ${widget.turno.operador}');
    buffer.writeln('📋 *Turno:* #${widget.turno.numero}');
    buffer.writeln('📅 *Aberto em:* ${widget.turno.data}');
    if (widget.turno.fechadoEm != null && widget.turno.fechadoEm!.isNotEmpty) {
      buffer.writeln('⏱️ *Fechado em:* ${widget.turno.fechadoEm}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    buffer.writeln('💳 *CARTÕES E VOUCHERS:*');
    if (widget.totais.detalheCartoes.isEmpty) {
      buffer.writeln('  _Nenhum cartão registrado_');
    } else {
      for (final e in PaymentTypes.ordenarCartoes(widget.totais.detalheCartoes.entries)) {
        buffer.writeln('  • ${e.key}: ${CurrencyFormatter.formatar(e.value.total)} (${e.value.qtd} un)');
      }
    }
    buffer.writeln('  👉 *Total Cartões:* ${CurrencyFormatter.formatar(widget.totais.cartoes)} (${widget.totais.qtdCartoes} un)');
    buffer.writeln('');

    buffer.writeln('💵 *OUTROS MEIOS:*');
    buffer.writeln('  • Pag Pix: ${CurrencyFormatter.formatar(widget.totais.pix)}');
    buffer.writeln('  • Sobra de Dinheiro: ${CurrencyFormatter.formatar(widget.totais.dinheiro)}');
    if (widget.totais.requisicao > 0) {
      buffer.writeln('  • Requisição: ${CurrencyFormatter.formatar(widget.totais.requisicao)}');
    }
    if (widget.totais.depositoGlobal > 0) {
      buffer.writeln('  • Depósito Global: ${CurrencyFormatter.formatar(widget.totais.depositoGlobal)}');
    }
    if (widget.totais.despesas > 0) {
      buffer.writeln('  • Despesas: ${CurrencyFormatter.formatar(widget.totais.despesas)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');

    buffer.writeln('🧮 *TOTAL VENDAS PISTA:* ${CurrencyFormatter.formatar(widget.totais.totalGeral)}');
    if (_vendasSistema > 0) {
      buffer.writeln('🖥️ *VENDAS SISTEMA (PDV):* ${CurrencyFormatter.formatar(_vendasSistema)}');
      final dif = _diferencaAtual;
      if (dif.abs() < 0.01) {
        buffer.writeln('✅ *STATUS:* CAIXA 100% BATIDO (SEM DIFERENÇA)');
      } else if (dif > 0) {
        buffer.writeln('🔺 *STATUS:* SOBRA DE ${CurrencyFormatter.formatar(dif)}');
      } else {
        buffer.writeln('🔻 *STATUS:* FALTA DE ${CurrencyFormatter.formatar(dif)}');
      }
    }

    if (_observacao.trim().isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📝 *Observações:* $_observacao');
    }

    return buffer.toString();
  }

  // 1. WhatsApp
  void _compartilharWhatsApp(BuildContext btnContext) async {
    final texto = _montarTextoResumo();
    final origin = _obterOrigemCompartilhamento(btnContext);
    try {
      await Share.share(
        texto,
        subject: 'Fechamento Turno #${widget.turno.numero} - ${widget.turno.operador}',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao compartilhar: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  // 2. Copiar Texto
  void _copiarTexto() async {
    final texto = _montarTextoResumo();
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Resumo copiado para a área de transferência!'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 3. Baixar PDF
  void _baixarPdf(BuildContext btnContext) async {
    setState(() => _processando = true);
    final origin = _obterOrigemCompartilhamento(btnContext);

    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(widget.turno.id!);
      final turnoAtualizado = widget.turno.copyWith(
        vendasSistema: _vendasSistema,
        observacao: _observacao,
      );

      final nomeArquivo = PdfService.gerarNomeArquivo(turno: turnoAtualizado);
      final pdfBytes = await PdfService.gerarPdfFechamento(
        turno: turnoAtualizado,
        totais: _totaisAtualizados,
        lancamentos: lancamentos,
      );

      final caminhoLocal = await PdfService.salvarArquivoLocal(
        pdfBytes: pdfBytes,
        nomeArquivo: nomeArquivo,
      );

      if (!kIsWeb && caminhoLocal != null) {
        await Share.shareXFiles(
          [XFile(caminhoLocal)],
          subject: 'Fechamento de Turno - ${widget.turno.operador}',
          sharePositionOrigin: origin,
        );
      } else {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: nomeArquivo,
          bounds: origin,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar/compartilhar PDF: $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // 4. Excel (CSV)
  void _exportarExcel(BuildContext btnContext) async {
    setState(() => _processando = true);

    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(widget.turno.id!);
      final turnoAtualizado = widget.turno.copyWith(
        vendasSistema: _vendasSistema,
        observacao: _observacao,
      );

      await CsvService.exportarECompartilharCsv(
        turno: turnoAtualizado,
        totais: _totaisAtualizados,
        lancamentos: lancamentos,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar CSV: $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // 5. Encerrar Turno com Animação e Feedback Imediato
  void _encerrarTurno() async {
    if (!widget.turno.aberto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este turno já está encerrado.'), backgroundColor: AppColors.amber),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text(
              'Encerrar Turno?',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.lightTextPri,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja fechar o Turno #${widget.turno.numero} do operador ${widget.turno.operador}?\n\n'
          'Total Pista: ${CurrencyFormatter.formatar(widget.totais.totalGeral)}\n'
          'Vendas Sistema: ${CurrencyFormatter.formatar(_vendasSistema)}\n'
          'Diferença: ${CurrencyFormatter.formatar(_diferencaAtual)}',
          style: TextStyle(
            color: isDark ? const Color(0xFFCBD5E1) : AppColors.lightTextSec,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sim, Encerrar Turno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Diálogo de Progresso Animado
    final progressoNotifier = ValueNotifier<String>('Fechando turno no banco de dados...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ValueListenableBuilder<String>(
              valueListenable: progressoNotifier,
              builder: (context, status, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF38BDF8),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ENCERRANDO TURNO',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPri,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    try {
      final db = DatabaseService.instance;
      
      // Executa fechamento do banco e busca de lançamentos em paralelo para máxima velocidade
      final results = await Future.wait([
        db.fecharTurno(
          widget.turno.id!,
          vendasSistema: _vendasSistema,
          observacao: _observacao,
        ),
        db.obterLancamentos(widget.turno.id!),
      ]);
      final lancamentos = results[1] as List<Lancamento>;

      progressoNotifier.value = 'Gerando relatório PDF corporativo...';
      final dataHoraFechamento = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final turnoFechado = widget.turno.copyWith(
        aberto: false,
        vendasSistema: _vendasSistema,
        observacao: _observacao,
        fechadoEm: dataHoraFechamento,
      );

      final nomeArquivo = PdfService.gerarNomeArquivo(turno: turnoFechado);
      final pdfBytes = await PdfService.gerarPdfFechamento(
        turno: turnoFechado,
        totais: _totaisAtualizados,
        lancamentos: lancamentos,
      );

      progressoNotifier.value = 'Enviando PDF para o Google Drive do gerente...';
      final resultadoDrive = await DriveService.enviarPdfDrive(
        pdfBytes: pdfBytes,
        nomeArquivo: nomeArquivo,
        turnoId: widget.turno.id!,
        operador: widget.turno.operador,
        turnoNumero: widget.turno.numero,
      );

      progressoNotifier.value = '✅ Concluído com sucesso!';
      await Future.delayed(const Duration(milliseconds: 150));

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Fecha diálogo de progresso
      }

      if (!mounted) return;

      widget.onTurnoAlterado();

      if (!resultadoDrive.sucesso) {
        showDialog(
          context: context,
          builder: (ctx) => DriveFailureDialog(
            turnoNumero: widget.turno.numero,
            operador: widget.turno.operador,
            mensagemErro: resultadoDrive.mensagem,
            onSincronizado: () {
              widget.onTurnoAlterado();
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Turno encerrado com sucesso! ${resultadoDrive.mensagem}'),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao encerrar turno: $e'), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diferenca = _diferencaAtual;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgScaffold = isDark ? const Color(0xFF0D131F) : AppColors.lightBg;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Column(
          children: [
            PendingSyncBanner(onSincronizado: widget.onTurnoAlterado),
            // ── Barra Superior com Ícone de Barras e Fechar 'X' ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Resumo do Turno',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textPri,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSec),
                    onPressed: () {
                      if (widget.onFechar != null) {
                        widget.onFechar!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderCol),

            // ── Conteúdo com Scroll Dinâmico e Botões Integrados ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status do Turno (Aberto / Fechado)
                    if (!widget.turno.aberto) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_rounded, color: Color(0xFFF87171), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'TURNO ENCERRADO (${widget.turno.fechadoEm ?? "Fechado"})',
                                style: const TextStyle(
                                  color: Color(0xFFF87171),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── 1. SEÇÃO DE CARTÕES E VOUCHERS (Bandeiras com Vendas e Total) ──
                    if (widget.totais.detalheCartoes.values.any((v) => v.total > 0)) ...[
                      Text(
                        'CARTÕES E VOUCHERS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final e in PaymentTypes.ordenarCartoes(widget.totais.detalheCartoes.entries))
                        if (e.value.total > 0) ...[
                          _itemResumoCard(
                            icon: Icons.credit_card_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBg: isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE),
                            titulo: e.key,
                            subtitulo: '(${e.value.qtd} un)',
                            valor: e.value.total,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                        ],
                      if (widget.totais.cartoes > 0 || widget.totais.qtdCartoes > 0) ...[
                        _itemResumoCard(
                          icon: Icons.credit_card_rounded,
                          iconColor: const Color(0xFF0284C7),
                          iconBg: isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFE0F2FE),
                          titulo: 'Total Cartões',
                          subtitulo: '(${widget.totais.qtdCartoes} un)',
                          valor: widget.totais.cartoes,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],

                    // ── 2. SEÇÃO DE OUTRAS FORMAS DE PAGAMENTO ──
                    if (widget.totais.dinheiro > 0 ||
                        widget.totais.pix > 0 ||
                        widget.totais.requisicao > 0 ||
                        widget.totais.depositoGlobal > 0 ||
                        widget.totais.despesas > 0) ...[
                      Text(
                        'OUTRAS FORMAS DE PAGAMENTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Sobra de Dinheiro
                      if (widget.totais.dinheiro > 0) ...[
                        _itemResumoCard(
                          icon: Icons.money_rounded,
                          iconColor: const Color(0xFF059669),
                          iconBg: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFD1FAE5),
                          titulo: 'Sobra de Dinheiro',
                          valor: widget.totais.dinheiro,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Pag Pix
                      if (widget.totais.pix > 0) ...[
                        _itemResumoCard(
                          icon: Icons.qr_code_2_rounded,
                          iconColor: const Color(0xFF0284C7),
                          iconBg: isDark ? const Color(0xFF0C4A6E).withOpacity(0.5) : const Color(0xFFE0F2FE),
                          titulo: 'Pag Pix',
                          subtitulo: '(${widget.totais.pix > 0 ? "1" : "0"} un)',
                          valor: widget.totais.pix,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Requisição
                      if (widget.totais.requisicao > 0) ...[
                        _itemResumoCard(
                          icon: Icons.receipt_long_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          iconBg: isDark ? const Color(0xFF581C87).withOpacity(0.5) : const Color(0xFFF3E8FF),
                          titulo: 'Requisição',
                          valor: widget.totais.requisicao,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Depósito Global
                      if (widget.totais.depositoGlobal > 0) ...[
                        _itemResumoCard(
                          icon: Icons.account_balance_rounded,
                          iconColor: const Color(0xFFD97706),
                          iconBg: isDark ? const Color(0xFF78350F).withOpacity(0.5) : const Color(0xFFFEF3C7),
                          titulo: 'Depósito Global',
                          valor: widget.totais.depositoGlobal,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Despesas
                      if (widget.totais.despesas > 0) ...[
                        _itemResumoCard(
                          icon: Icons.money_off_rounded,
                          iconColor: const Color(0xFFDC2626),
                          iconBg: isDark ? const Color(0xFF7F1D1D).withOpacity(0.5) : const Color(0xFFFEE2E2),
                          titulo: 'Despesas',
                          valor: widget.totais.despesas,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    // ── 3. CASO NADA TENHA SIDO LANÇADO AINDA ──
                    if (widget.totais.totalGeral == 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131C2E) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum lançamento registrado no turno',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'CONCILIAÇÃO DE VENDAS DO CAIXA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Card Total de Vendas Pista ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF111C38) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.point_of_sale_rounded, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'TOTAL DE VENDAS PISTA:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            CurrencyFormatter.formatar(widget.totais.totalGeral),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Input Total de Vendas Sistema (PDV) ──
                    TextFormField(
                      controller: _vendasSistemaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [CurrencyInputFormatter()],
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.lightTextPri,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'TOTAL DE VENDAS SISTEMA (PDV)',
                        labelStyle: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: Icon(
                          Icons.computer_rounded,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF131C2E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: _atualizarVendasSistema,
                    ),
                    const SizedBox(height: 10),

                    // ── Card de Status da Diferença ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: diferenca.abs() < 0.01
                            ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFD1FAE5))
                            : (diferenca > 0
                                ? (isDark ? const Color(0xFF78350F).withOpacity(0.3) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF7F1D1D).withOpacity(0.3) : const Color(0xFFFEE2E2))),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: diferenca.abs() < 0.01
                              ? const Color(0xFF10B981)
                              : (diferenca > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            diferenca.abs() < 0.01
                                ? Icons.check_circle_rounded
                                : (diferenca > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                            color: diferenca.abs() < 0.01
                                ? const Color(0xFF10B981)
                                : (diferenca > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              diferenca.abs() < 0.01
                                  ? 'CAIXA 100% BATIDO (SEM DIFERENÇA)'
                                  : (diferenca > 0 ? 'SOBRA NA PISTA' : 'FALTA NA PISTA'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: diferenca.abs() < 0.01
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                    : (diferenca > 0
                                        ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))
                                        : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B))),
                              ),
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatar(diferenca),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: diferenca.abs() < 0.01
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                  : (diferenca > 0
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E))
                                      : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Input Observações / Justificativa ──
                    TextFormField(
                      controller: _observacaoController,
                      maxLines: 2,
                      style: TextStyle(color: isDark ? Colors.white : AppColors.lightTextPri, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'OBSERVAÇÕES / JUSTIFICATIVA',
                        labelStyle: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF131C2E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: _atualizarObservacao,
                    ),
                    const SizedBox(height: 16),

                    // ── 6 Botões de Ação Integrados Dinamicamente na Página ──
                    Builder(
                      builder: (btnCtx) {
                        final neutralBtnBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                        final neutralBtnText = isDark ? Colors.white : const Color(0xFF1E293B);

                        return Column(
                          children: [
                            // Linha 1: WhatsApp | Copiar Texto | Baixar PDF
                            Row(
                              children: [
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.chat_rounded,
                                    label: 'WhatsApp',
                                    corFundo: const Color(0xFF16A34A),
                                    corTexto: Colors.white,
                                    onPressed: _processando ? null : () => _compartilharWhatsApp(btnCtx),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.copy_rounded,
                                    label: 'Copiar Texto',
                                    corFundo: neutralBtnBg,
                                    corTexto: neutralBtnText,
                                    onPressed: _copiarTexto,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.picture_as_pdf_rounded,
                                    label: 'Baixar PDF',
                                    corFundo: neutralBtnBg,
                                    corTexto: neutralBtnText,
                                    onPressed: _processando ? null : () => _baixarPdf(btnCtx),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Linha 2: Excel (CSV) | Encerrar Turno | Fechar
                            Row(
                              children: [
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.table_chart_rounded,
                                    label: 'Excel (CSV)',
                                    corFundo: const Color(0xFF0D9488),
                                    corTexto: Colors.white,
                                    onPressed: _processando ? null : () => _exportarExcel(btnCtx),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.lock_rounded,
                                    label: widget.turno.aberto ? 'Encerrar Turno' : 'Turno Fechado',
                                    corFundo: widget.turno.aberto ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                    corTexto: Colors.white,
                                    onPressed: _processando ? null : _encerrarTurno,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.close_rounded,
                                    label: 'Fechar',
                                    corFundo: neutralBtnBg,
                                    corTexto: neutralBtnText,
                                    onPressed: () {
                                      if (widget.onFechar != null) {
                                        widget.onFechar!();
                                      } else {
                                        Navigator.maybePop(context);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemResumoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    String? subtitulo,
    required double valor,
    VoidCallback? onTap,
    bool showChevron = false,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF131C2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final textTitle = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final textValue = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              titulo,
              style: TextStyle(fontSize: 14, color: textTitle, fontWeight: FontWeight.w600),
            ),
            if (subtitulo != null) ...[
              const SizedBox(width: 6),
              Text(
                subtitulo,
                style: TextStyle(fontSize: 12, color: textSub),
              ),
            ],
            const Spacer(),
            Text(
              CurrencyFormatter.formatar(valor),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textValue),
            ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: textSub, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _botaoAcao({
    required IconData icon,
    required String label,
    required Color corFundo,
    required Color corTexto,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: corFundo,
          foregroundColor: corTexto,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: corTexto),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: corTexto,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
