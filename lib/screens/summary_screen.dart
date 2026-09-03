import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dialogs/close_shift_dialog.dart';
import '../dialogs/drive_failure_dialog.dart';
import '../models/lancamento.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
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
  Timer? _debounceTimer;
  Map<String, int> _canhotosManual = {};
  bool _processando = false;
  bool _cartoesExpandidos = false;

  @override
  void initState() {
    super.initState();
    _canhotosManual = Map<String, int>.from(widget.turno.canhotos);
    _vendasSistema = widget.turno.vendasSistema;
    _observacao = widget.turno.textoJustificativa;

    if (_vendasSistema > 0) {
      _vendasSistemaController.text = CurrencyFormatter.formatar(_vendasSistema);
    }
    _observacaoController.text = _observacao;

    _recarregarDadosPersistidos();
  }

  Future<void> _recarregarDadosPersistidos() async {
    if (widget.turno.id == null) return;
    try {
      final turnoDb = await DatabaseService.instance.obterTurnoPorId(widget.turno.id!);
      if (turnoDb != null && mounted) {
        setState(() {
          if (turnoDb.vendasSistema > 0 && _vendasSistema == 0.0) {
            _vendasSistema = turnoDb.vendasSistema;
            _vendasSistemaController.text = CurrencyFormatter.formatar(_vendasSistema);
          }
          if (turnoDb.textoJustificativa.isNotEmpty && _observacao.isEmpty) {
            _observacao = turnoDb.textoJustificativa;
            _observacaoController.text = _observacao;
          }
          if (turnoDb.canhotos.isNotEmpty && _canhotosManual.isEmpty) {
            _canhotosManual = Map<String, int>.from(turnoDb.canhotos);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant SummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turno.id != widget.turno.id ||
        oldWidget.turno.vendasSistema != widget.turno.vendasSistema ||
        oldWidget.turno.observacao != widget.turno.observacao ||
        oldWidget.turno.justificativa != widget.turno.justificativa ||
        oldWidget.turno.canhotos != widget.turno.canhotos) {
      _vendasSistema = widget.turno.vendasSistema;
      _observacao = widget.turno.textoJustificativa;
      _vendasSistemaController.text = _vendasSistema > 0 ? CurrencyFormatter.formatar(_vendasSistema) : '';
      _observacaoController.text = _observacao;
      _canhotosManual = Map<String, int>.from(widget.turno.canhotos);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (widget.turno.id != null) {
        DatabaseService.instance.salvarAuditoria(
          widget.turno.id!,
          _vendasSistema,
          _observacao,
          justificativa: _observacao,
          canhotos: _canhotosManual,
        );
      }
    });
  }

  void _atualizarObservacao(String text) {
    _observacao = text;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (widget.turno.id != null) {
        DatabaseService.instance.salvarAuditoria(
          widget.turno.id!,
          _vendasSistema,
          _observacao,
          justificativa: _observacao,
          canhotos: _canhotosManual,
        );
      }
    });
  }

  void _salvarNovoCanhoto(String bandeira, int novaQtd) async {
    setState(() {
      _canhotosManual[bandeira] = novaQtd;
    });
    if (widget.turno.id != null) {
      await DatabaseService.instance.salvarCanhotos(widget.turno.id!, _canhotosManual);
    }
    widget.onTurnoAlterado();
  }

  void _dialogEditarCanhoto(String bandeira, int qtdAtual, [VoidCallback? onUpdate]) {
    final controller = TextEditingController(text: qtdAtual.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Canhotos: $bandeira',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.lightTextPri,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Informe a quantidade de comprovantes/canhotos físicos recolhidos no caixa:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantidade de Canhotos',
                  suffixText: 'un',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final novaQtd = int.tryParse(controller.text.trim()) ?? qtdAtual;
                Navigator.of(ctx).pop();
                _salvarNovoCanhoto(bandeira, novaQtd >= 0 ? novaQtd : 0);
                if (onUpdate != null) onUpdate();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
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
        final qtdCanhotos = _canhotosManual[e.key] ?? e.value.qtd;
        buffer.writeln('  • ${e.key}: ${CurrencyFormatter.formatar(e.value.total)} ($qtdCanhotos un)');
      }
    }
    final totalCanhotosGeral = widget.totais.detalheCartoes.entries.fold<int>(
      0,
      (acc, e) => acc + (_canhotosManual[e.key] ?? e.value.qtd),
    );
    buffer.writeln('  👉 *Total Cartões:* ${CurrencyFormatter.formatar(widget.totais.cartoes)} ($totalCanhotosGeral un)');
    buffer.writeln('');

    buffer.writeln('💵 *OUTROS MEIOS:*');
    final qtdPixTexto = widget.totais.qtdPix > 0 ? ' (${widget.totais.qtdPix} un)' : '';
    buffer.writeln('  • Pag Pix: ${CurrencyFormatter.formatar(widget.totais.pix)}$qtdPixTexto');
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
      buffer.writeln('📝 *Observações / Justificativa:* $_observacao');
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
        justificativa: _observacao,
        canhotos: _canhotosManual,
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
        justificativa: _observacao,
        canhotos: _canhotosManual,
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

  // 5. Encerrar Turno com Autenticação de PIN e Assinatura Digital SHA-256
  void _encerrarTurno() async {
    if (!widget.turno.aberto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Este turno já foi homologado e encerrado!'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    // Persistir obrigatoriamente a venda do sistema digitada e justificativa antes do fechamento
    final valorDigitado = CurrencyFormatter.parse(_vendasSistemaController.text);
    _vendasSistema = valorDigitado;
    final obsDigitada = _observacaoController.text.trim();
    _observacao = obsDigitada;

    if (widget.turno.id != null) {
      await DatabaseService.instance.salvarAuditoria(
        widget.turno.id!,
        _vendasSistema,
        _observacao,
        justificativa: _observacao,
        canhotos: _canhotosManual,
      );
    }

    final turnoAtualizado = widget.turno.copyWith(
      vendasSistema: _vendasSistema,
      observacao: _observacao,
      justificativa: _observacao,
      canhotos: _canhotosManual,
    );

    DadosFechamentoTurno? dadosFechamento;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CloseShiftDialog(
        turno: turnoAtualizado,
        totais: _totaisAtualizados,
        onConfirmarFechamento: (dados) {
          dadosFechamento = dados;
        },
      ),
    );

    if (dadosFechamento == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Diálogo de Progresso Animado
    final progressoNotifier = ValueNotifier<String>('Autenticando e gravando turno no banco...');
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
                      'HOMOLOGANDO TURNO',
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
      
      final obsFechamento = dadosFechamento!.observacao.trim().isNotEmpty
          ? dadosFechamento!.observacao.trim()
          : _observacao;

      // Executa fechamento do banco e busca de lançamentos sequencialmente
      await db.fecharTurno(
        widget.turno.id!,
        vendasSistema: dadosFechamento!.vendasSistema,
        observacao: obsFechamento,
        justificativa: obsFechamento,
        canhotos: _canhotosManual,
        authHash: dadosFechamento!.authHash,
        dataFechamento: dadosFechamento!.fechadoEm,
      );
      final lancamentos = await db.obterLancamentos(widget.turno.id!);

      progressoNotifier.value = 'Gerando relatório PDF autenticado digitalmente...';
      final turnoFechado = widget.turno.copyWith(
        aberto: false,
        vendasSistema: dadosFechamento!.vendasSistema,
        observacao: obsFechamento,
        justificativa: obsFechamento,
        canhotos: _canhotosManual,
        fechadoEm: dadosFechamento!.fechadoEm,
        authHash: dadosFechamento!.authHash,
      );

      final nomeArquivo = PdfService.gerarNomeArquivo(turno: turnoFechado);
      final pdfBytes = await PdfService.gerarPdfFechamento(
        turno: turnoFechado,
        totais: _totaisAtualizados.copyWith(
          vendasSistema: dadosFechamento!.vendasSistema,
          diferenca: widget.totais.totalGeral - dadosFechamento!.vendasSistema,
        ),
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

      // Redefine a preferência de máquina ativa para Rede ao fechar o turno
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('maquina_ativa', PaymentTypes.maquinaRede);
      } catch (_) {}

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
            content: Text(resultadoDrive.mensagem),
            backgroundColor: AppColors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      progressoNotifier.dispose();
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) {
        progressoNotifier.dispose();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao encerrar turno: $e'), backgroundColor: AppColors.red),
      );
      progressoNotifier.dispose();
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
            // ── Barra Superior com Ícone em Gradiente, Chips e Fechar 'X' ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
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
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo do Turno',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: textPri,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: DriveService.modoTesteNotifier,
                    builder: (context, modoTeste, _) {
                      if (!modoTeste) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🧪', style: TextStyle(fontSize: 10)),
                            SizedBox(width: 4),
                            Text(
                              'TESTE',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textSec,
                    splashRadius: 18,
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
                    // Banner de Modo Teste no Resumo
                    ValueListenableBuilder<bool>(
                      valueListenable: DriveService.modoTesteNotifier,
                      builder: (context, modoTeste, _) {
                        if (!modoTeste) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF78350F).withOpacity(0.35),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Row(
                            children: [
                              Text('🧪', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'MODO TESTE ATIVO: O PDF deste fechamento será enviado para a pasta de homologação do Drive.',
                                  style: TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Status do Turno (Aberto / Fechado)
                    if (!widget.turno.aberto) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF7F1D1D).withOpacity(isDark ? 0.35 : 0.12),
                              const Color(0xFF991B1B).withOpacity(isDark ? 0.25 : 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.6), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded, color: Color(0xFFF87171), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TURNO HOMOLOGADO E FECHADO',
                                    style: TextStyle(
                                      color: Color(0xFFF87171),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Encerrado em: ${widget.turno.fechadoEm ?? "Fechado"}',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── 1. SEÇÃO DE CARTÕES E VOUCHERS (Bandeiras com Vendas e Total) ──
                    if (widget.totais.detalheCartoes.values.any((v) => v.total > 0)) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CARTÕES E VOUCHERS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                              letterSpacing: 0.6,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${widget.totais.detalheCartoes.entries.fold<int>(0, (acc, e) => acc + (_canhotosManual[e.key] ?? e.value.qtd))} un',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final e in PaymentTypes.ordenarCartoes(widget.totais.detalheCartoes.entries))
                        if (e.value.total > 0) ...[
                          _itemResumoCard(
                            icon: AppColors.getIconeTipo(e.key),
                            iconColor: AppColors.getCorTipo(e.key),
                            iconBg: isDark
                                ? AppColors.getCorTipo(e.key).withOpacity(0.18)
                                : AppColors.getCorTipo(e.key).withOpacity(0.12),
                            titulo: e.key,
                            subtitulo: '${_canhotosManual[e.key] ?? e.value.qtd} un',
                            onTapSubtitulo: () => _dialogEditarCanhoto(e.key, _canhotosManual[e.key] ?? e.value.qtd),
                            valor: e.value.total,
                            isDark: isDark,
                            showChevron: true,
                            onTap: () => _abrirDetalhesCartao(e.key),
                          ),
                          const SizedBox(height: 8),
                        ],
                      if (widget.totais.cartoes > 0 || widget.totais.qtdCartoes > 0) ...[
                        _itemResumoCard(
                          icon: Icons.credit_card_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          iconBg: isDark ? const Color(0xFF0284C7).withOpacity(0.25) : const Color(0xFFE0F2FE),
                          titulo: 'Total Cartões e Vouchers',
                          subtitulo: '${widget.totais.detalheCartoes.entries.fold<int>(0, (acc, e) => acc + (_canhotosManual[e.key] ?? e.value.qtd))} un',
                          valor: widget.totais.cartoes,
                          isDark: isDark,
                          isSummaryCard: true,
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
                          subtitulo: '${widget.totais.qtdPix} un',
                          valor: widget.totais.pix,
                          isDark: isDark,
                          onTap: () => _abrirDetalhesCartao('Pag Pix'),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONCILIAÇÃO DE VENDAS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Auditoria',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Card Hero Total de Vendas Pista ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1E3A8A).withOpacity(0.55), const Color(0xFF0F172A)]
                              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF38BDF8).withOpacity(0.4) : const Color(0xFF3B82F6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          if (isDark)
                            BoxShadow(
                              color: const Color(0xFF1E3A8A).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF38BDF8), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TOTAL DE VENDAS PISTA',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.formatar(widget.totais.totalGeral),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: textPri,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
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
                        color: textPri,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Vendas Sistema (Relatório PDV)',
                        labelStyle: TextStyle(
                          color: textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(
                          Icons.computer_rounded,
                          color: Color(0xFF38BDF8),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: _atualizarVendasSistema,
                    ),
                    const SizedBox(height: 10),

                    // ── Card de Status da Diferença ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: diferenca.abs() < 0.01
                            ? (isDark ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFFD1FAE5))
                            : (diferenca > 0
                                ? (isDark ? const Color(0xFF78350F).withOpacity(0.35) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF7F1D1D).withOpacity(0.35) : const Color(0xFFFEE2E2))),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: diferenca.abs() < 0.01
                              ? const Color(0xFF10B981)
                              : (diferenca > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: (diferenca.abs() < 0.01
                                      ? const Color(0xFF10B981)
                                      : (diferenca > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)))
                                  .withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              diferenca.abs() < 0.01
                                  ? Icons.check_circle_rounded
                                  : (diferenca > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                              color: diferenca.abs() < 0.01
                                  ? const Color(0xFF10B981)
                                  : (diferenca > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              diferenca.abs() < 0.01
                                  ? 'CONCILIAÇÃO 100% BATIDA'
                                  : (diferenca > 0 ? 'SOBRA NA PISTA' : 'FALTA NA PISTA'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
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
                      style: TextStyle(color: textPri, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Observações / Justificativa (Opcional)',
                        labelStyle: TextStyle(
                          color: textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF111827) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: _atualizarObservacao,
                    ),
                    const SizedBox(height: 16),

                    // ── 6 Botões de Ação Executivos Integrados Dinamicamente na Página ──
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
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF16A34A).withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0D9488).withOpacity(0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    onPressed: _processando ? null : () => _exportarExcel(btnCtx),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.lock_rounded,
                                    label: widget.turno.aberto ? 'Encerrar Turno' : 'Turno Fechado',
                                    corFundo: widget.turno.aberto ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                                    corTexto: Colors.white,
                                    gradient: widget.turno.aberto
                                        ? const LinearGradient(
                                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    boxShadow: widget.turno.aberto
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
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
    VoidCallback? onTapSubtitulo,
    bool showChevron = false,
    bool isSummaryCard = false,
    required bool isDark,
  }) {
    final cardBg = isSummaryCard
        ? (isDark ? const Color(0xFF172554).withOpacity(0.4) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF111827) : Colors.white);
    final cardBorder = isSummaryCard
        ? (isDark ? const Color(0xFF3B82F6).withOpacity(0.5) : const Color(0xFFBFDBFE))
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final textTitle = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final textValue = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final textoBadge = subtitulo != null
        ? subtitulo.replaceAll('(', '').replaceAll(')', '').trim()
        : null;

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.light();
              onTap();
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder, width: isSummaryCard ? 1.2 : 1),
          boxShadow: [
            if (!isDark || isSummaryCard)
              BoxShadow(
                color: isSummaryCard
                    ? const Color(0xFF3B82F6).withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7.5),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isSummaryCard && isDark ? const Color(0xFF93C5FD) : textTitle,
                  fontWeight: isSummaryCard ? FontWeight.w800 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (textoBadge != null && textoBadge.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildBadgeUnidade(
                texto: textoBadge,
                onTap: onTapSubtitulo,
                isDark: isDark,
                isSummaryCard: isSummaryCard,
              ),
            ],
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 100),
              alignment: Alignment.centerRight,
              child: Text(
                CurrencyFormatter.formatar(valor),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isSummaryCard && isDark ? const Color(0xFF38BDF8) : textValue,
                ),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: textSub, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeUnidade({
    required String texto,
    VoidCallback? onTap,
    required bool isDark,
    bool isSummaryCard = false,
  }) {
    final badgeBg = const Color(0xFF3B82F6).withOpacity(isDark ? 0.18 : 0.12);
    final badgeBorder = const Color(0xFF3B82F6).withOpacity(isDark ? 0.28 : 0.22);
    final badgeTextCol = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    final badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeBorder, width: 0.8),
      ),
      child: Text(
        texto,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeTextCol,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(6),
          child: badgeContent,
        ),
      );
    }

    return badgeContent;
  }

  Widget _botaoAcao({
    required IconData icon,
    required String label,
    required Color corFundo,
    required Color corTexto,
    required VoidCallback? onPressed,
    Gradient? gradient,
    List<BoxShadow>? boxShadow,
  }) {
    return SizedBox(
      height: 46,
      child: Container(
        decoration: BoxDecoration(
          color: gradient == null ? corFundo : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: boxShadow,
        ),
        child: ElevatedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  AppHaptics.light();
                  onPressed();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: corTexto,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: corTexto),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: corTexto,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDetalhesCartao(String bandeira) async {
    final db = DatabaseService.instance;
    final todosLancamentos = await db.obterLancamentos(widget.turno.id!);
    final ehPix = bandeira == 'Pag Pix' || bandeira == PaymentTypes.pix;
    var lancamentosBandeira = ehPix
        ? todosLancamentos.where((l) => PaymentTypes.ehPix(l.tipo)).toList()
        : todosLancamentos.where((l) => l.tipo == bandeira).toList();

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corTipo = AppColors.getCorTipo(bandeira);
    final iconeTipo = AppColors.getIconeTipo(bandeira);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusXl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final totalBandeira = lancamentosBandeira.fold<double>(0.0, (acc, l) => acc + l.valor);
            final qtdBandeira = lancamentosBandeira.length;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
            final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;
            final cardBg = isDark ? const Color(0xFF131C2E) : const Color(0xFFF8FAFC);

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle superior do modal
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cabeçalho da Bandeira / Forma de Pagamento
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: corTipo.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(iconeTipo, color: corTipo, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bandeira,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPri,
                                ),
                              ),
                              Text(
                                '$qtdBandeira lançamento(s) • Total: ${CurrencyFormatter.formatar(totalBandeira)}',
                                style: TextStyle(fontSize: 12, color: textSec),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSec),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(height: 1, color: borderCol),
                    const SizedBox(height: 12),

                    // Ajuste de Canhotos Físicos (exclusivo para cartões)
                    if (!ehPix) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Canhotos Físicos (QTD)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: textPri,
                                  ),
                                ),
                                Text(
                                  'Base de vendas: $qtdBandeira un',
                                  style: TextStyle(fontSize: 10.5, color: textSec),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                  color: AppColors.red,
                                  onPressed: () {
                                    final atual = _canhotosManual[bandeira] ?? qtdBandeira;
                                    if (atual > 0) {
                                      _salvarNovoCanhoto(bandeira, atual - 1);
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                                InkWell(
                                  onTap: () => _dialogEditarCanhoto(
                                    bandeira,
                                    _canhotosManual[bandeira] ?? qtdBandeira,
                                    () => setSheetState(() {}),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF0284C7)),
                                    ),
                                    child: Text(
                                      '${_canhotosManual[bandeira] ?? qtdBandeira} un',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                  color: AppColors.green,
                                  onPressed: () {
                                    final atual = _canhotosManual[bandeira] ?? qtdBandeira;
                                    _salvarNovoCanhoto(bandeira, atual + 1);
                                    setSheetState(() {});
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Lista de Lançamentos
                    if (lancamentosBandeira.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Nenhum lançamento restante.',
                            style: TextStyle(color: textSec, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: lancamentosBandeira.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final l = lancamentosBandeira[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: corTipo.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${l.id ?? index + 1}',
                                      style: TextStyle(
                                        color: corTipo,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatar(l.valor),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: corTipo,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 11, color: textSec),
                                            const SizedBox(width: 3),
                                            Text(
                                              l.hora,
                                              style: TextStyle(fontSize: 11, color: textSec),
                                            ),
                                            if (l.descricao.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Text('•', style: TextStyle(fontSize: 11, color: textSec)),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  l.descricao,
                                                  style: TextStyle(fontSize: 11, color: textSec),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (!widget.turno.aberto)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF78350F).withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.lock_rounded, size: 13, color: Color(0xFFFBBF24)),
                                          SizedBox(width: 4),
                                          Text('Bloqueado', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                                        ],
                                      ),
                                    )
                                  else ...[
                                    // Botão Editar
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF38BDF8)),
                                      tooltip: 'Editar valor',
                                      onPressed: () async {
                                        final result = await _editarLancamentoDialog(context, l);
                                        if (result != null) {
                                          await db.atualizarLancamento(
                                            l.id!,
                                            widget.turno.id!,
                                            l.tipo,
                                            result.valor,
                                            result.descricao,
                                          );
                                          widget.onTurnoAlterado();
                                          final atualizados = await db.obterLancamentos(widget.turno.id!);
                                          setSheetState(() {
                                            lancamentosBandeira = ehPix
                                                ? atualizados.where((item) => PaymentTypes.ehPix(item.tipo)).toList()
                                                : atualizados.where((item) => item.tipo == bandeira).toList();
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('✅ Lançamento atualizado com sucesso!'),
                                                backgroundColor: AppColors.green,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),

                                    // Botão Excluir
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.red),
                                      tooltip: 'Excluir lançamento',
                                      onPressed: () async {
                                        final confirmar = await _confirmarExclusaoDialog(context, l);
                                        if (confirmar == true) {
                                          await db.deletarLancamento(l.id!, widget.turno.id!);
                                          widget.onTurnoAlterado();
                                          final atualizados = await db.obterLancamentos(widget.turno.id!);
                                          final restantes = ehPix
                                              ? atualizados.where((item) => PaymentTypes.ehPix(item.tipo)).toList()
                                              : atualizados.where((item) => item.tipo == bandeira).toList();
                                          if (restantes.isEmpty) {
                                            if (mounted && Navigator.canPop(sheetContext)) {
                                              Navigator.pop(sheetContext);
                                            }
                                          } else {
                                            setSheetState(() {
                                              lancamentosBandeira = restantes;
                                            });
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🗑️ Lançamento excluído com sucesso!'),
                                                backgroundColor: AppColors.red,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<({double valor, String descricao})?> _editarLancamentoDialog(BuildContext context, Lancamento l) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final controllerValor = TextEditingController(text: CurrencyFormatter.formatar(l.valor));
    final controllerDesc = TextEditingController(text: l.descricao);
    String? erro;

    final resultado = await showDialog<({double valor, String descricao})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Editar Lançamento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bandeira: ${l.tipo}',
                    style: TextStyle(fontSize: 12, color: textSec, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controllerValor,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: 'Novo Valor (R\$)',
                      errorText: erro,
                      prefixIcon: const Icon(Icons.attach_money_rounded),
                      filled: true,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (erro != null) setDialogState(() => erro = null);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controllerDesc,
                    decoration: const InputDecoration(
                      labelText: 'Descrição / Placa (Opcional)',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancelar', style: TextStyle(color: textSec)),
              ),
              ElevatedButton(
                onPressed: () {
                  final valor = CurrencyFormatter.parse(controllerValor.text);
                  if (valor <= 0) {
                    setDialogState(() => erro = 'Informe um valor maior que zero');
                    return;
                  }
                  Navigator.pop(ctx, (valor: valor, descricao: controllerDesc.text.trim()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    controllerValor.dispose();
    controllerDesc.dispose();
    return resultado;
  }

  Future<bool?> _confirmarExclusaoDialog(BuildContext context, Lancamento l) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 22),
            const SizedBox(width: 8),
            Text(
              'Excluir Lançamento?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
            ),
          ],
        ),
        content: Text(
          'Deseja remover o lançamento de ${CurrencyFormatter.formatar(l.valor)} em ${l.tipo} (Horário: ${l.hora})?\n\n'
          'Os totais do turno serão recalculados automaticamente.',
          style: TextStyle(fontSize: 13, color: textSec, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: textSec)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sim, Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
