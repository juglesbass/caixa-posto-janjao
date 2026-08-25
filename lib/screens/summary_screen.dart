import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../dialogs/close_shift_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class SummaryScreen extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final VoidCallback onTurnoAlterado;

  const SummaryScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.onTurnoAlterado,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _gerandoPdf = false;
  bool _enviandoDrive = false;

  void _fecharTurno() async {
    await showDialog(
      context: context,
      builder: (ctx) => CloseShiftDialog(
        turno: widget.turno,
        totais: widget.totais,
        onConfirmarFechamento: (dados) async {
          final db = DatabaseService.instance;
          await db.fecharTurno(
            widget.turno.id!,
            vendasSistema: dados.vendasSistema,
            observacao: dados.observacao,
          );

          // Gera o PDF e envia para o Google Drive automaticamente
          _gerarEEnviarPdf(dados.vendasSistema, dados.observacao);

          widget.onTurnoAlterado();
        },
      ),
    );
  }

  void _gerarEEnviarPdf([double? vendasSistema, String? obs]) async {
    setState(() {
      _gerandoPdf = true;
      _enviandoDrive = true;
    });

    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(widget.turno.id!);
      final turnoAtualizado = widget.turno.copyWith(
        vendasSistema: vendasSistema ?? widget.turno.vendasSistema,
        observacao: obs ?? widget.turno.observacao,
        fechadoEm: widget.turno.fechadoEm ?? 'Agora',
      );

      final pdfBytes = await PdfService.gerarPdfFechamento(
        turno: turnoAtualizado,
        totais: widget.totais,
        lancamentos: lancamentos,
      );

      final nomeArquivo = 'Fechamento_Turno_${widget.turno.numero}_${widget.turno.data.replaceAll('/', '-').replaceAll(':', '').replaceAll(' ', '_')}.pdf';

      // 1. Envio para o Google Drive
      final resultadoDrive = await DriveService.enviarPdfDrive(
        pdfBytes: pdfBytes,
        nomeArquivo: nomeArquivo,
        turnoId: widget.turno.id!,
        operador: widget.turno.operador,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultadoDrive.mensagem),
          backgroundColor: resultadoDrive.sucesso ? AppColors.green : AppColors.amber,
          duration: const Duration(seconds: 4),
        ),
      );

      // 2. Opção de Compartilhar no WhatsApp / Imprimir
      await Printing.sharePdf(bytes: pdfBytes, filename: nomeArquivo);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar/enviar PDF: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      setState(() {
        _gerandoPdf = false;
        _enviandoDrive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Resumo do Turno #${widget.turno.numero}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accentLight),
            tooltip: 'Gerar / Compartilhar PDF',
            onPressed: _gerandoPdf ? null : () => _gerarEEnviarPdf(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Card de Status do Turno ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Operador:', style: TextStyle(color: textSec, fontSize: 13)),
                      Text(
                        widget.turno.operador,
                        style: TextStyle(fontWeight: FontWeight.bold, color: textPri, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aberto em:', style: TextStyle(color: textSec, fontSize: 13)),
                      Text(
                        widget.turno.data,
                        style: TextStyle(fontWeight: FontWeight.w600, color: textPri, fontSize: 13),
                      ),
                    ],
                  ),
                  if (widget.turno.fechadoEm != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fechado em:', style: TextStyle(color: textSec, fontSize: 13)),
                        Text(
                          widget.turno.fechadoEm!,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.red, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Detalhamento de Cartões ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CARTÕES E VOUCHERS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple),
                      ),
                      Text(
                        'Total: ${CurrencyFormatter.formatar(widget.totais.cartoes)} (${widget.totais.qtdCartoes} un)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 8),
                  if (widget.totais.detalheCartoes.isEmpty)
                    Text('Nenhum cartão registrado neste turno.', style: TextStyle(color: textSec, fontSize: 12))
                  else
                    ...widget.totais.detalheCartoes.entries.map((e) {
                      final nome = e.key;
                      final valor = e.value.total;
                      final qtd = e.value.qtd;
                      final cor = AppColors.getCorTipo(nome);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$nome ($qtd un)',
                              style: TextStyle(fontSize: 13, color: textPri),
                            ),
                            Text(
                              CurrencyFormatter.formatar(valor),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cor),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Totais Financeiros ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _linhaFinanceira('Dinheiro em Espécie:', widget.totais.dinheiro, AppColors.green, textPri),
                  const SizedBox(height: 6),
                  _linhaFinanceira('Pagamento Pix:', widget.totais.pix, AppColors.blue, textPri),
                  if (widget.totais.requisicao > 0) ...[
                    const SizedBox(height: 6),
                    _linhaFinanceira('Requisição:', widget.totais.requisicao, AppColors.amber, textPri),
                  ],
                  if (widget.totais.depositoGlobal > 0) ...[
                    const SizedBox(height: 6),
                    _linhaFinanceira('Depósito Global:', widget.totais.depositoGlobal, AppColors.brown, textPri),
                  ],
                  if (widget.totais.despesas > 0) ...[
                    const SizedBox(height: 6),
                    _linhaFinanceira('Despesas:', widget.totais.despesas, AppColors.red, textPri),
                  ],
                  const SizedBox(height: 10),
                  Divider(height: 1, color: borderColor),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL GERAL:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textPri)),
                      Text(
                        CurrencyFormatter.formatar(widget.totais.totalGeral),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.accentLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Gaveta e Sangrias ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  if (widget.totais.fundoCaixa > 0) ...[
                    _linhaFinanceira('Fundo de Caixa (Inicial):', widget.totais.fundoCaixa, textSec, textPri),
                    const SizedBox(height: 6),
                  ],
                  if (widget.totais.sangrias > 0) ...[
                    _linhaFinanceira('Sangrias p/ Cofre (${widget.totais.qtdSangrias} un):', widget.totais.sangrias, AppColors.orange, textPri),
                    const SizedBox(height: 6),
                  ],
                  _linhaFinanceira('Dinheiro na Gaveta (Atual):', widget.totais.dinheiroGaveta, AppColors.green, textPri, isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Botões de Ação ──
            if (widget.turno.aberto) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _fecharTurno,
                  icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
                  label: const Text('FECHAR TURNO E GERAR PDF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final db = DatabaseService.instance;
                    await db.reabrirTurno(widget.turno.id!);
                    widget.onTurnoAlterado();
                  },
                  icon: const Icon(Icons.lock_open_rounded, color: AppColors.accentLight),
                  label: const Text('REABRIR ESTE TURNO', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentLight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _linhaFinanceira(String label, double valor, Color corValor, Color textPri, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
        Text(
          CurrencyFormatter.formatar(valor),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: corValor,
          ),
        ),
      ],
    );
  }
}
