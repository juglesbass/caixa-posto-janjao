import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// `printing` e `pdf_service` (mais abaixo) são diferidos: juntos eles trazem os
// pacotes `pdf` e `printing`, o trecho mais pesado do pacote JavaScript, e só
// fazem falta quando alguém pede o PDF. Carregados na abertura por
// [DriveService.aquecerPdf], ficam prontos antes do primeiro uso.
import 'package:printing/printing.dart' deferred as printing;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dialogs/close_shift_dialog.dart';
import '../dialogs/drive_failure_dialog.dart';
import '../models/lancamento.dart';
import '../models/motivo_pendencia.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart' deferred as pdf_service;
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/conciliacao.dart';
import '../utils/currency_formatter.dart';
import '../utils/data_caixa.dart';
import '../utils/payment_types.dart';
import '../widgets/cabecalho_turno.dart';
import '../widgets/pending_sync_banner.dart';

class SummaryScreen extends StatefulWidget {
  final Turno turno;
  final TotaisTurno totais;
  final VoidCallback onTurnoAlterado;
  final VoidCallback? onFechar;

  /// Recarrega o turno sem a tela de carregamento inteira — usado ao trocar a
  /// data do caixa. Sem ele, cai em [onTurnoAlterado].
  final VoidCallback? onDadosAlterados;

  const SummaryScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.onTurnoAlterado,
    this.onFechar,
    this.onDadosAlterados,
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

    // Só recarrega os campos do zero quando realmente mudou de turno. Antes a
    // comparação incluía o Map de canhotos (nunca igual entre instâncias), então
    // qualquer lançamento novo reconstruía a tela e apagava o valor em digitação.
    if (oldWidget.turno.id != widget.turno.id) {
      _vendasSistema = widget.turno.vendasSistema;
      _observacao = widget.turno.textoJustificativa;
      _vendasSistemaController.text = _vendasSistema > 0 ? CurrencyFormatter.formatar(_vendasSistema) : '';
      _observacaoController.text = _observacao;
      _canhotosManual = Map<String, int>.from(widget.turno.canhotos);
      return;
    }

    // Mesmo turno: só absorve valores vindos do banco em campos ainda intocados
    if (_vendasSistema == 0.0 && widget.turno.vendasSistema > 0) {
      _vendasSistema = widget.turno.vendasSistema;
      _vendasSistemaController.text = CurrencyFormatter.formatar(_vendasSistema);
    }
    if (_observacao.isEmpty && widget.turno.textoJustificativa.isNotEmpty) {
      _observacao = widget.turno.textoJustificativa;
      _observacaoController.text = _observacao;
    }
    if (_canhotosManual.isEmpty && widget.turno.canhotos.isNotEmpty) {
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
              onPressed: () {
                Navigator.of(ctx).pop();
                _abrirDetalhesCartao(bandeira);
              },
              child: const Text('Ver Detalhes'),
            ),
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
    buffer.writeln('🗓️ *Caixa do dia:* ${widget.turno.dataCaixa}');
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
      switch (Conciliacao.estado(totalPista: widget.totais.totalGeral, vendasSistema: _vendasSistema)) {
        case EstadoConciliacao.fechada:
          buffer.writeln('✅ *STATUS:* CAIXA 100% BATIDO (SEM DIFERENÇA)');
        case EstadoConciliacao.sobra:
          buffer.writeln('🔺 *STATUS:* SOBRA DE ${CurrencyFormatter.formatar(dif)}');
        case EstadoConciliacao.falta:
          buffer.writeln('🔻 *STATUS:* FALTA DE ${CurrencyFormatter.formatar(dif)}');
        case EstadoConciliacao.semSistema:
          break;
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
      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject: 'Fechamento Turno #${widget.turno.numero} - ${widget.turno.operador}',
          sharePositionOrigin: origin,
        ),
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

      await pdf_service.loadLibrary();
      final nomeArquivo =
          pdf_service.PdfService.gerarNomeArquivo(turno: turnoAtualizado);
      final pdfBytes = await pdf_service.PdfService.gerarPdfFechamento(
        turno: turnoAtualizado,
        totais: _totaisAtualizados,
        lancamentos: lancamentos,
      );

      final caminhoLocal = await pdf_service.PdfService.salvarArquivoLocal(
        pdfBytes: pdfBytes,
        nomeArquivo: nomeArquivo,
      );

      if (!kIsWeb && caminhoLocal != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(caminhoLocal, mimeType: 'application/pdf')],
            subject: 'Fechamento de Turno - ${widget.turno.operador}',
            sharePositionOrigin: origin,
          ),
        );
      } else {
        await printing.loadLibrary();
        await printing.Printing.sharePdf(
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

  /// Dia a que o caixa pertence, com a opção de trocar antes de fechar.
  ///
  /// É por essa data que a gerência confere, e ela vai no nome do PDF. Fica
  /// visível aqui para o operador notar antes de fechar se escolheu errado na
  /// abertura — depois de fechado, só reabrindo o turno.
  Widget _linhaDataCaixa(Color textSec) {
    final podeTrocar = widget.turno.aberto && widget.turno.id != null;
    return InkWell(
      onTap: podeTrocar ? _trocarDataCaixa : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded, size: 14, color: textSec),
            const SizedBox(width: 4),
            // Encolhe com reticencias em vez de estourar: celular estreito ou
            // letra do sistema aumentada. O "trocar" fica sempre inteiro.
            Flexible(
              child: Text(
                'Caixa do dia ${widget.turno.dataCaixa}',
                style: TextStyle(fontSize: AppTexto.rotulo, color: textSec, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (podeTrocar) ...[
              const SizedBox(width: 8),
              const Text(
                'trocar',
                style: TextStyle(
                  fontSize: AppTexto.rotulo,
                  color: AppColors.accentLight,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _trocarDataCaixa() async {
    final turnoId = widget.turno.id;
    final opcoes = DataCaixa.opcoesParaTroca(widget.turno.data, DateTime.now());
    if (turnoId == null || opcoes.isEmpty) return;
    final atual = widget.turno.dataCaixa;

    Widget botao(BuildContext ctx, String rotulo, String data) {
      final selecionada = data == atual;
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: selecionada ? AppColors.accent : null,
          foregroundColor: selecionada ? Colors.white : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => Navigator.of(ctx).pop(data),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selecionada) ...[
              const Icon(Icons.check_rounded, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              '$rotulo — ${DataCaixa.curta(data)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('De qual dia é este caixa?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aberto em ${widget.turno.data}.\n\n'
              'Essa data vai no nome do PDF e no cabeçalho do fechamento.',
            ),
            const SizedBox(height: 8),
            for (final opcao in opcoes) ...[
              const SizedBox(height: 10),
              botao(ctx, opcao.rotulo, opcao.data),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (escolha == null || escolha == atual || !mounted) return;

    final alterou = await DatabaseService.instance.alterarDataCaixa(turnoId, escolha);
    if (!mounted) return;

    if (!alterou) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível trocar a data: o turno não está mais aberto.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    (widget.onDadosAlterados ?? widget.onTurnoAlterado)();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Caixa agora é do dia $escolha.'),
        backgroundColor: AppColors.green,
      ),
    );
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

    // Carregado uma vez aqui, e não junto de cada uso: mais abaixo o nome do
    // arquivo é calculado dentro de um `try` que engole falhas, e é ele que grava
    // a pendência do Drive. Garantir o pedaço agora impede que uma falha de
    // carregamento faça o fechamento perder a pendência em silêncio. Fica depois
    // da guarda de turno já encerrado para que ela siga respondendo na hora, sem
    // passar por um `await`.
    //
    // Se o carregamento falhar, o turno NÃO é fechado (seguro), mas antes nada
    // aparecia: o operador tocava em "Encerrar Turno" e não acontecia nada.
    try {
      await pdf_service.loadLibrary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível preparar o PDF do fechamento. Feche e abra o app '
            'e tente de novo — o turno continua aberto.',
          ),
          backgroundColor: AppColors.red,
          duration: Duration(seconds: 6),
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

    // Diálogo de Progresso com Animações Dinâmicas (PDF -> Drive -> Sucesso)
    final progressoNotifier = ValueNotifier<({
      String titulo,
      String subtitulo,
      IconData icone,
      Color corTema,
      bool carregando,
    })>((
      titulo: 'HOMOLOGANDO TURNO',
      subtitulo: 'Autenticando e gravando turno no banco local...',
      icone: Icons.lock_clock_rounded,
      corTema: const Color(0xFF38BDF8),
      carregando: true,
    ));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ValueListenableBuilder(
              valueListenable: progressoNotifier,
              builder: (context, estado, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(estado.titulo),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: estado.corTema.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: estado.corTema, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: estado.corTema.withValues(alpha: 0.25),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: estado.carregando
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: CircularProgressIndicator(
                                        color: estado.corTema,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    Icon(
                                      estado.icone,
                                      color: estado.corTema,
                                      size: 22,
                                    ),
                                  ],
                                )
                              : Icon(
                                  estado.icone,
                                  color: estado.corTema,
                                  size: 42,
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        estado.titulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: estado.carregando
                              ? (isDark ? Colors.white : AppColors.lightTextPri)
                              : estado.corTema,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        estado.subtitulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    bool envioDriveOk = false;

    // Enquanto este fechamento envia, a pendência dele fica fora do banner e da
    // fila (ver DatabaseService.enviosDriveEmCurso).
    final turnoIdEnvio = widget.turno.id;
    if (turnoIdEnvio != null) {
      DatabaseService.enviosDriveEmCurso.add(turnoIdEnvio);
    }

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
        // A pendência nasce na mesma transação do fechamento: se o app for
        // fechado no meio do envio, o PDF continua na fila em vez de sumir.
        pendenciaNomeArquivo:
            pdf_service.PdfService.gerarNomeArquivo(turno: widget.turno),
        pendenciaOperador: widget.turno.operador,
      );
      final lancamentos = await db.obterLancamentos(widget.turno.id!);

      progressoNotifier.value = (
        titulo: 'GERANDO RELATÓRIO',
        subtitulo: 'Criando documento PDF autenticado digitalmente...',
        icone: Icons.picture_as_pdf_rounded,
        corTema: const Color(0xFF38BDF8),
        carregando: true,
      );
      final turnoFechado = widget.turno.copyWith(
        aberto: false,
        vendasSistema: dadosFechamento!.vendasSistema,
        observacao: obsFechamento,
        justificativa: obsFechamento,
        canhotos: _canhotosManual,
        fechadoEm: dadosFechamento!.fechadoEm,
        authHash: dadosFechamento!.authHash,
      );

      final nomeArquivo =
          pdf_service.PdfService.gerarNomeArquivo(turno: turnoFechado);
      final pdfBytes = await pdf_service.PdfService.gerarPdfFechamento(
        turno: turnoFechado,
        totais: _totaisAtualizados.copyWith(
          vendasSistema: dadosFechamento!.vendasSistema,
          diferenca: widget.totais.totalGeral - dadosFechamento!.vendasSistema,
        ),
        lancamentos: lancamentos,
      );

      progressoNotifier.value = (
        titulo: 'ENVIANDO AO GOOGLE DRIVE',
        subtitulo: 'Entregando fechamento na pasta oficial do gerente...',
        icone: Icons.cloud_upload_rounded,
        corTema: const Color(0xFF60A5FA),
        carregando: true,
      );
      final resultadoDrive = await DriveService.enviarPdfDrive(
        pdfBytes: pdfBytes,
        nomeArquivo: nomeArquivo,
        turnoId: widget.turno.id!,
        operador: widget.turno.operador,
        turnoNumero: widget.turno.numero,
        authHash: dadosFechamento!.authHash,
        aoConfirmarEntrega: () {
          progressoNotifier.value = (
            titulo: 'CONFIRMANDO ENTREGA',
            subtitulo: 'O Google demorou a responder. Conferindo se o PDF chegou à pasta...',
            icone: Icons.fact_check_rounded,
            corTema: const Color(0xFF60A5FA),
            carregando: true,
          );
        },
      );

      envioDriveOk = resultadoDrive.sucesso;

      if (envioDriveOk) {
        // Validação direta: garante limpeza imediata de qualquer resíduo na fila offline
        try {
          await DatabaseService.instance.removerPendenciaDrive(widget.turno.id!);
          await NotificationService.atualizarPendencias();
        } catch (_) {}
      }

      // Redefine a preferência de máquina ativa para Rede ao fechar o turno
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('maquina_ativa', PaymentTypes.maquinaRede);
      } catch (_) {}

      if (envioDriveOk) {
        progressoNotifier.value = (
          titulo: 'ENTREGUE COM SUCESSO!',
          subtitulo: resultadoDrive.mensagem,
          icone: Icons.cloud_done_rounded,
          corTema: const Color(0xFF10B981),
          carregando: false,
        );
        AppHaptics.medium();
        await Future.delayed(const Duration(milliseconds: 1400));
      } else {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Fecha diálogo de progresso
      }

      if (!mounted) return;

      widget.onTurnoAlterado();

      if (!envioDriveOk) {
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
      try {
        progressoNotifier.dispose();
      } catch (_) {}
    } catch (e) {
      // SÓ salva na fila offline se o upload NÃO tiver sido concluído com sucesso.
      // Se o envio ao Drive já obteve confirmação HTTP, qualquer falha posterior
      // (ex: na interface ou transição de tela) NUNCA deve gerar falso positivo de pendência.
      try {
        if (!envioDriveOk && widget.turno.id != null) {
          final turnoNoBanco = await DatabaseService.instance.obterTurnoPorId(widget.turno.id!);
          if (turnoNoBanco != null && !turnoNoBanco.aberto) {
            // Chegar a este catch é erro do próprio app (montar o PDF, ler o
            // banco): o envio ao Drive não lança exceção.
            await DatabaseService.instance.salvarPendenciaDrive(
              widget.turno.id!,
              pdf_service.PdfService.gerarNomeArquivo(turno: turnoNoBanco),
              widget.turno.operador,
              motivo: MotivoPendencia.erroApp,
            );
            await NotificationService.atualizarPendencias();
          }
        }
      } catch (_) {}

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (!mounted) {
        try {
          progressoNotifier.dispose();
        } catch (_) {}
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao encerrar turno: $e'),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      try {
        progressoNotifier.dispose();
      } catch (_) {}
    } finally {
      if (turnoIdEnvio != null) {
        DatabaseService.enviosDriveEmCurso.remove(turnoIdEnvio);
      }
      // Agora o banner pode mostrar a pendência, se o envio não se confirmou
      unawaited(NotificationService.atualizarPendencias());
    }
  }

  @override
  Widget build(BuildContext context) {
    final diferenca = _diferencaAtual;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Mesmo fundo da tela Inicio: ao trocar de aba, a tela nao muda de tom.
    final bgScaffold = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final qtdCartoes = widget.totais.detalheCartoes.entries
        .fold<int>(0, (acc, e) => acc + (_canhotosManual[e.key] ?? e.value.qtd));
    final temOutras = widget.totais.dinheiro > 0 ||
        widget.totais.pix > 0 ||
        widget.totais.requisicao > 0 ||
        widget.totais.depositoGlobal > 0 ||
        widget.totais.despesas > 0;

    InputDecoration campo(String rotulo, IconData icone) => InputDecoration(
          labelText: rotulo,
          labelStyle: TextStyle(color: textSec, fontSize: AppTexto.corpo, fontWeight: FontWeight.w600),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 17, right: 8),
            child: Icon(icone, color: AppColors.accentLight, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 44),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: BorderSide(color: borderCol),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: BorderSide(color: borderCol),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.accentLight, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        );

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Column(
          children: [
            PendingSyncBanner(onSincronizado: widget.onTurnoAlterado),
            // ── Cabeçalho: que caixa é este, de quem, e sair ──
            Container(
              color: surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Resumo do caixa',
                          style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          widget.turno.operador,
                          style: TextStyle(fontSize: AppTexto.rotulo, color: textSec, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _linhaDataCaixa(textSec),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: DriveService.modoTesteNotifier,
                    builder: (context, modoTeste, _) => modoTeste
                        ? const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SeloTurno(texto: 'Teste', cor: AppColors.amber),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (!widget.turno.aberto)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: SeloTurno(texto: 'Fechado', cor: AppColors.amber),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: textSec,
                    tooltip: 'Fechar',
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modo teste: o PDF vai para a pasta de homologacao.
                    ValueListenableBuilder<bool>(
                      valueListenable: DriveService.modoTesteNotifier,
                      builder: (context, modoTeste, _) {
                        if (!modoTeste) return const SizedBox.shrink();
                        return const _Aviso(
                          cor: AppColors.amber,
                          icone: Icons.science_rounded,
                          titulo: 'Modo teste ligado',
                          texto: 'O PDF deste fechamento vai para a pasta de homologação do Drive.',
                        );
                      },
                    ),
                    // Turno ja encerrado
                    if (!widget.turno.aberto)
                      _Aviso(
                        cor: AppColors.red,
                        icone: Icons.lock_rounded,
                        titulo: 'Turno fechado',
                        texto: 'Encerrado em ${widget.turno.fechadoEm ?? "—"}.',
                      ),

                    // ── 1. Cartões e vouchers ──
                    if (widget.totais.detalheCartoes.values.any((v) => v.total > 0))
                      _Bloco(
                        titulo: 'Cartões e vouchers',
                        contagem: '$qtdCartoes×',
                        children: [
                          for (final e in PaymentTypes.ordenarCartoes(widget.totais.detalheCartoes.entries))
                            if (e.value.total > 0)
                              _LinhaResumo(
                                icone: AppColors.getIconeTipo(e.key),
                                cor: AppColors.getCorTipo(e.key),
                                titulo: e.key,
                                quantidade: '${_canhotosManual[e.key] ?? e.value.qtd}×',
                                valor: e.value.total,
                                onTap: () => _abrirDetalhesCartao(e.key),
                              ),
                          if (widget.totais.cartoes > 0 || widget.totais.qtdCartoes > 0)
                            _LinhaTotal(titulo: 'Total cartões e vouchers', valor: widget.totais.cartoes),
                        ],
                      ),

                    // ── 2. Outras formas de pagamento ──
                    if (temOutras)
                      _Bloco(
                        titulo: 'Outras formas de pagamento',
                        children: [
                          if (widget.totais.dinheiro > 0)
                            _LinhaResumo(
                              icone: AppIcones.dinheiro,
                              cor: AppColors.green,
                              titulo: 'Sobra de Dinheiro',
                              valor: widget.totais.dinheiro,
                            ),
                          if (widget.totais.pix > 0)
                            _LinhaResumo(
                              icone: AppIcones.pix,
                              cor: AppColors.blue,
                              titulo: 'Pag Pix',
                              quantidade: '${widget.totais.qtdPix}×',
                              valor: widget.totais.pix,
                              onTap: () => _abrirDetalhesCartao('Pag Pix'),
                            ),
                          if (widget.totais.requisicao > 0)
                            _LinhaResumo(
                              icone: AppIcones.requisicao,
                              cor: AppColors.amber,
                              titulo: 'Requisição',
                              valor: widget.totais.requisicao,
                            ),
                          if (widget.totais.depositoGlobal > 0)
                            _LinhaResumo(
                              icone: AppIcones.deposito,
                              cor: AppColors.brown,
                              titulo: 'Depósito Global',
                              valor: widget.totais.depositoGlobal,
                            ),
                          if (widget.totais.despesas > 0)
                            _LinhaResumo(
                              icone: AppIcones.despesas,
                              cor: AppColors.red,
                              titulo: 'Despesas',
                              valor: widget.totais.despesas,
                            ),
                        ],
                      ),

                    // ── Nada lançado ainda ──
                    if (widget.totais.totalGeral == 0)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppColors.radiusLg),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded, color: textSec, size: 34),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum lançamento neste turno ainda.',
                              style: TextStyle(color: textSec, fontSize: AppTexto.corpo),
                            ),
                          ],
                        ),
                      ),

                    // ── 3. Conciliação de vendas ──
                    _Bloco(
                      titulo: 'Conciliação de vendas',
                      children: [
                        _LinhaTotal(titulo: 'Total de vendas pista', valor: widget.totais.totalGeral, grande: true),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _vendasSistemaController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [CurrencyInputFormatter()],
                                style: TextStyle(color: textPri, fontWeight: FontWeight.w800, fontSize: AppTexto.valor),
                                decoration: campo('Vendas do sistema (relatório PDV)', Icons.computer_rounded),
                                onChanged: _atualizarVendasSistema,
                              ),
                              const SizedBox(height: 10),
                              _FaixaConciliacao(
                                diferenca: diferenca,
                                estado: Conciliacao.estado(
                                  totalPista: widget.totais.totalGeral,
                                  vendasSistema: _vendasSistema,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Observações ──
                    TextFormField(
                      controller: _observacaoController,
                      maxLines: 2,
                      style: TextStyle(color: textPri, fontSize: AppTexto.corpo),
                      decoration: campo('Observações / justificativa (opcional)', Icons.edit_note_rounded),
                      onChanged: _atualizarObservacao,
                    ),
                    const SizedBox(height: 18),

                    // ── Ações ──
                    Builder(
                      builder: (btnCtx) {
                        return Column(
                          children: [
                            // Acao principal, sozinha e larga: depois dela o
                            // PDF sai e o gerente recebe. Nao pode ter o mesmo
                            // peso de um botao que copia texto.
                            SizedBox(
                              width: double.infinity,
                              child: _botaoAcao(
                                icon: Icons.lock_rounded,
                                label: widget.turno.aberto ? 'Encerrar turno e enviar ao gerente' : 'Turno fechado',
                                corFundo: widget.turno.aberto
                                    ? AppColors.accent
                                    : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                                corTexto: widget.turno.aberto ? Colors.white : textSec,
                                altura: 52,
                                principal: true,
                                onPressed: _processando ? null : _encerrarTurno,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // As quatro saidas do encerrante, com o mesmo peso
                            // entre si: o pessoal usa todas, e nenhuma delas
                            // mexe no caixa.
                            Row(
                              children: [
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.chat_rounded,
                                    label: 'WhatsApp',
                                    corFundo: surface,
                                    corTexto: textPri,
                                    corIcone: const Color(0xFF16A34A),
                                    onPressed: _processando ? null : () => _compartilharWhatsApp(btnCtx),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.copy_rounded,
                                    label: 'Copiar texto',
                                    corFundo: surface,
                                    corTexto: textPri,
                                    corIcone: AppColors.accentLight,
                                    onPressed: _copiarTexto,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.picture_as_pdf_rounded,
                                    label: 'Baixar PDF',
                                    corFundo: surface,
                                    corTexto: textPri,
                                    corIcone: AppColors.red,
                                    onPressed: _processando ? null : () => _baixarPdf(btnCtx),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _botaoAcao(
                                    icon: Icons.table_chart_rounded,
                                    label: 'Excel (CSV)',
                                    corFundo: surface,
                                    corTexto: textPri,
                                    corIcone: AppColors.teal,
                                    onPressed: _processando ? null : () => _exportarExcel(btnCtx),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Sair da tela nao e acao de caixa: fica discreto e
                            // por ultimo, longe do Encerrar turno.
                            SizedBox(
                              width: double.infinity,
                              child: _botaoAcao(
                                icon: Icons.close_rounded,
                                label: 'Fechar',
                                corFundo: Colors.transparent,
                                corTexto: textSec,
                                semBorda: true,
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

  Widget _botaoAcao({
    required IconData icon,
    required String label,
    required Color corFundo,
    required Color corTexto,
    required VoidCallback? onPressed,
    // Icone colorido sobre fundo neutro: a cor identifica a saida (WhatsApp,
    // PDF, Excel) sem pintar o botao inteiro e sem competir com a acao
    // principal, que e a unica azul da tela.
    Color? corIcone,
    double altura = 48,
    bool principal = false,
    bool semBorda = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return SizedBox(
      height: altura,
      child: ElevatedButton(
        onPressed: onPressed == null
            ? null
            : () {
                AppHaptics.light();
                onPressed();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: corFundo,
          disabledBackgroundColor: corFundo.withValues(alpha: corFundo.a * 0.6),
          foregroundColor: corTexto,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            side: principal || semBorda ? BorderSide.none : BorderSide(color: borderCol),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: principal ? 18 : 17, color: corIcone ?? corTexto),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: principal ? AppTexto.corpo + 1 : AppTexto.corpo,
                  fontWeight: principal ? FontWeight.w800 : FontWeight.w700,
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
                            color: corTipo.withValues(alpha: 0.18),
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
                            // Ocupa so o que sobra: os botoes - e + nunca podem
                            // ser empurrados para fora num celular estreito.
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Canhotos Físicos (QTD)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: textPri,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Base de vendas: $qtdBandeira un',
                                    style: TextStyle(fontSize: 10.5, color: textSec),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
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
                                      color: corTipo.withValues(alpha: 0.12),
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
                                        color: const Color(0xFF78350F).withValues(alpha: 0.3),
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

    if (mounted) {
      setState(() {});
      widget.onTurnoAlterado();
    }
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

/// Um bloco do Resumo: título em caixa alta, e as linhas num cartão só,
/// separadas por fio — como no PDF que o gerente recebe, e não um cartão por
/// linha.
class _Bloco extends StatelessWidget {
  final String titulo;
  final String? contagem;
  final List<Widget> children;

  const _Bloco({required this.titulo, this.contagem, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;

    final linhas = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) linhas.add(Divider(height: 1, thickness: 1, color: borderCol));
      linhas.add(children[i]);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: TextStyle(
                      fontSize: AppTexto.rotulo,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: textTer,
                    ),
                  ),
                ),
                if (contagem != null)
                  Text(
                    contagem!,
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textTer, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppColors.radiusLg),
              border: Border.all(color: borderCol),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: linhas),
          ),
        ],
      ),
    );
  }
}

/// Uma forma de pagamento no Resumo: ícone na cor dela, nome, quantidade e o
/// valor em dígitos alinhados. Quando tem detalhe, a linha inteira abre.
class _LinhaResumo extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String? quantidade;
  final double valor;
  final VoidCallback? onTap;

  const _LinhaResumo({
    required this.icone,
    required this.cor,
    required this.titulo,
    this.quantidade,
    required this.valor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final corIcone = isDark && cor == AppColors.purple ? AppColors.purpleLight : cor;

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              AppHaptics.light();
              onTap!();
            },
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, onTap == null ? 16 : 8, 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: corIcone.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
              ),
              child: Icon(icone, size: 18, color: corIcone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: titulo),
                    if (quantidade != null)
                      TextSpan(
                        text: '  $quantidade',
                        style: TextStyle(color: textSec, fontWeight: FontWeight.w500, fontSize: AppTexto.rotulo),
                      ),
                  ],
                ),
                style: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w600, color: textPri),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CurrencyFormatter.formatar(valor),
              style: TextStyle(
                fontFamily: AppTexto.numeros,
                fontSize: AppTexto.valor,
                fontWeight: FontWeight.w600,
                color: textPri,
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: textTer),
          ],
        ),
      ),
    );
  }
}

/// Linha de total no pé (ou no topo) de um bloco: sem ícone, valor mais forte.
class _LinhaTotal extends StatelessWidget {
  final String titulo;
  final double valor;
  final bool grande;

  const _LinhaTotal({required this.titulo, required this.valor, this.grande = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final fundo = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;

    return Container(
      color: grande ? null : fundo,
      padding: EdgeInsets.fromLTRB(16, grande ? 14 : 12, 16, grande ? 10 : 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w700, color: textPri),
            ),
          ),
          Text(
            CurrencyFormatter.formatar(valor),
            style: TextStyle(
              fontSize: grande ? 22 : AppTexto.valor,
              fontWeight: FontWeight.w800,
              color: textPri,
            ),
          ),
        ],
      ),
    );
  }
}

/// O fecho da conciliação: pista fechada, sobra ou falta — ou, antes de
/// digitar as vendas do sistema, o que falta fazer.
class _FaixaConciliacao extends StatelessWidget {
  final double diferenca;
  final EstadoConciliacao estado;

  const _FaixaConciliacao({required this.diferenca, required this.estado});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Sem a venda do sistema nao ha conferencia (ver Conciliacao): em vez de
    // mostrar o total inteiro como "sobra", diz o que falta fazer.
    if (estado == EstadoConciliacao.semSistema) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: textSec),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Digite as vendas do sistema para conferir a pista.',
                style: TextStyle(fontSize: AppTexto.rotulo + 1, color: textSec),
              ),
            ),
          ],
        ),
      );
    }

    final fechada = estado == EstadoConciliacao.fechada;
    final sobra = estado == EstadoConciliacao.sobra;
    final cor = fechada ? AppColors.green : (sobra ? AppColors.amber : AppColors.red);
    final titulo = fechada ? 'Pista fechada' : (sobra ? 'Sobra na pista' : 'Falta na pista');
    final detalhe = fechada ? 'sem sobra, sem falta' : (sobra ? 'lançado a mais que o sistema' : 'lançado a menos que o sistema');
    final icone = fechada
        ? Icons.check_circle_rounded
        : (sobra ? Icons.trending_up_rounded : Icons.trending_down_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 22, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo.toUpperCase(),
                  style: TextStyle(fontSize: AppTexto.rotulo, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: cor),
                ),
                Text(detalhe, style: TextStyle(fontSize: AppTexto.rotulo, color: textSec)),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatar(diferenca),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cor),
          ),
        ],
      ),
    );
  }
}

/// Aviso no topo do Resumo (modo teste, turno fechado).
class _Aviso extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String titulo;
  final String texto;

  const _Aviso({required this.cor, required this.icone, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$titulo. ', style: TextStyle(fontWeight: FontWeight.w800, color: cor)),
                TextSpan(text: texto),
              ]),
              style: TextStyle(fontSize: AppTexto.rotulo + 1, color: textPri, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
