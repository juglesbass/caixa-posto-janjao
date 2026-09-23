import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';
import '../widgets/janela.dart';

class EncerrantesDialog extends StatefulWidget {
  final int turnoId;

  const EncerrantesDialog({super.key, required this.turnoId});

  @override
  State<EncerrantesDialog> createState() => _EncerrantesDialogState();
}

class _BicoItem {
  final String bico;
  final TextEditingController controllerCombustivel;
  final TextEditingController controllerPreco;
  final TextEditingController controllerLitros;

  _BicoItem({
    required this.bico,
    required String combustivel,
    required double preco,
    double litros = 0.0,
  })  : controllerCombustivel = TextEditingController(text: combustivel),
        controllerPreco = TextEditingController(text: preco > 0 ? preco.toStringAsFixed(2) : ''),
        controllerLitros = TextEditingController(text: litros > 0 ? litros.toStringAsFixed(2) : '');

  String get combustivel => controllerCombustivel.text.trim();
  double get preco => double.tryParse(controllerPreco.text.replaceAll(',', '.')) ?? 0.0;
  double get litrosVendidos => double.tryParse(controllerLitros.text.replaceAll(',', '.')) ?? 0.0;
  double get totalReais => litrosVendidos * preco;

  void dispose() {
    controllerCombustivel.dispose();
    controllerPreco.dispose();
    controllerLitros.dispose();
  }
}

class _EncerrantesDialogState extends State<EncerrantesDialog> {
  final List<_BicoItem> _bicos = [
    _BicoItem(bico: 'Bico 01', combustivel: 'Gasolina Comum', preco: 5.89),
    _BicoItem(bico: 'Bico 02', combustivel: 'Gasolina Aditivada', preco: 6.09),
    _BicoItem(bico: 'Bico 03', combustivel: 'Etanol Hidratado', preco: 3.99),
    _BicoItem(bico: 'Bico 04', combustivel: 'Diesel S10', preco: 5.99),
  ];

  static const List<String> _sugestoesCombustivel = [
    'Gasolina Comum',
    'Gasolina Aditivada',
    'Etanol Hidratado',
    'Diesel S10',
    'Diesel Comum',
    'GNV',
  ];

  @override
  void initState() {
    super.initState();
    _carregarSalvos();
  }

  @override
  void dispose() {
    for (final b in _bicos) {
      b.dispose();
    }
    super.dispose();
  }

  void _carregarSalvos() async {
    final db = DatabaseService.instance;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // 1. Carrega preferências salvas no aparelho (preços e nomes atualizados)
    for (final b in _bicos) {
      final combSalvo = prefs.getString('bico_${b.bico}_combustivel');
      if (combSalvo != null && combSalvo.isNotEmpty) {
        b.controllerCombustivel.text = combSalvo;
      }
      final precoSalvo = prefs.getDouble('bico_${b.bico}_preco');
      if (precoSalvo != null && precoSalvo > 0) {
        b.controllerPreco.text = precoSalvo.toStringAsFixed(2);
      }
    }

    // 2. Carrega os dados específicos salvos deste turno
    final salvos = await db.obterEncerrantes(widget.turnoId);
    if (!mounted) return;
    if (salvos.isNotEmpty) {
      if (_bicos.isEmpty) return;
      for (final s in salvos) {
        final bico = _bicos.firstWhere(
          (b) => b.bico == s['bico'],
          orElse: () => _bicos.first,
        );
        if (s['combustivel'] != null && (s['combustivel'] as String).isNotEmpty) {
          bico.controllerCombustivel.text = s['combustivel'];
        }
        if (s['preco'] != null && (s['preco'] as num) > 0) {
          bico.controllerPreco.text = (s['preco'] as num).toDouble().toStringAsFixed(2);
        }
        final finalVal = (s['final'] as num?)?.toDouble() ?? 0.0;
        final inicialVal = (s['inicial'] as num?)?.toDouble() ?? 0.0;
        final litros = finalVal > 0 && inicialVal > 0 ? (finalVal - inicialVal) : finalVal;
        bico.controllerLitros.text = litros > 0 ? litros.toStringAsFixed(2) : '';
      }
    }
    if (mounted) setState(() {});
  }

  void _adicionarBico() {
    final novoIndex = _bicos.length + 1;
    final nomeBico = 'Bico ${novoIndex.toString().padLeft(2, '0')}';
    setState(() {
      _bicos.add(_BicoItem(
        bico: nomeBico,
        combustivel: 'Gasolina Comum',
        preco: 5.89,
      ));
    });
  }

  void _removerBico(int index) {
    if (_bicos.length <= 1) return;
    setState(() {
      final removido = _bicos.removeAt(index);
      removido.dispose();
    });
  }

  void _salvar() async {
    final db = DatabaseService.instance;
    final prefs = await SharedPreferences.getInstance();

    for (final b in _bicos) {
      await db.salvarEncerrante(
        widget.turnoId,
        b.bico,
        b.combustivel,
        0.0, // Não necessita de leitura inicial
        b.litrosVendidos, // Salva diretamente os litros vendidos
        b.preco,
      );

      // Salva os valores de preço e combustível para lembrar no próximo turno
      await prefs.setString('bico_${b.bico}_combustivel', b.combustivel);
      await prefs.setDouble('bico_${b.bico}_preco', b.preco);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Encerrantes salvos com sucesso!'),
        backgroundColor: AppColors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }

  double get _totalLitrosGeral => _bicos.fold(0.0, (acc, b) => acc + b.litrosVendidos);
  double get _totalReaisGeral => _bicos.fold(0.0, (acc, b) => acc + b.totalReais);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    // Cada bico num bloco rebaixado; os campos, na cor da janela, saltam dele.
    final blocoBg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final inputBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    InputDecoration campo(String rotulo, {String? prefixo, String? sufixo, String? dica, Widget? fimIcone}) {
      return InputDecoration(
        labelText: rotulo,
        labelStyle: TextStyle(color: textSec, fontSize: AppTexto.rotulo),
        prefixText: prefixo,
        prefixStyle: TextStyle(fontSize: AppTexto.rotulo, color: textSec, fontWeight: FontWeight.w600),
        suffixText: sufixo,
        suffixStyle: TextStyle(fontSize: AppTexto.rotulo, color: textSec, fontWeight: FontWeight.w600),
        hintText: dica,
        hintStyle: TextStyle(color: textSec.withValues(alpha: 0.5)),
        suffixIcon: fimIcone,
        isDense: true,
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide(color: borderCol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide(color: borderCol),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      );
    }

    final estiloNumero = TextStyle(
      fontFamily: AppTexto.numeros,
      color: textPri,
      fontSize: AppTexto.corpo,
      fontWeight: FontWeight.w600,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            CabecalhoJanela(
              icone: Icons.local_gas_station_rounded,
              cor: AppColors.amber,
              titulo: 'Encerrantes de Bombas',
              subtitulo: 'Informe os litros vendidos e ajuste os preços por bico',
              onFechar: () => Navigator.of(context).pop(),
            ),
            Divider(color: borderCol, height: 24),

            // ── Lista de Bicos ──
            Expanded(
              child: ListView.separated(
                itemCount: _bicos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final bico = _bicos[index];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    decoration: BoxDecoration(
                      color: blocoBg,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nome do bico + excluir (só quando há mais de 4)
                        Row(
                          children: [
                            const Icon(Icons.local_gas_station_rounded, size: 16, color: AppColors.amber),
                            const SizedBox(width: 6),
                            Text(
                              bico.bico,
                              style: TextStyle(color: textPri, fontWeight: FontWeight.w700, fontSize: AppTexto.corpo),
                            ),
                            const Spacer(),
                            if (_bicos.length > 4)
                              IconButton(
                                onPressed: () => _removerBico(index),
                                tooltip: 'Remover ${bico.bico}',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.red),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Linha 1: Combustível Editável + Preço/L Editável
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: PopupMenuButton<String>(
                                tooltip: 'Selecionar combustível',
                                onSelected: (valor) {
                                  setState(() {
                                    bico.controllerCombustivel.text = valor;
                                  });
                                },
                                itemBuilder: (ctx) => _sugestoesCombustivel.map((comb) {
                                  return PopupMenuItem<String>(
                                    value: comb,
                                    child: Text(comb, style: const TextStyle(fontSize: AppTexto.corpo)),
                                  );
                                }).toList(),
                                child: TextField(
                                  controller: bico.controllerCombustivel,
                                  style: TextStyle(color: textPri, fontSize: AppTexto.corpo, fontWeight: FontWeight.w600),
                                  decoration: campo(
                                    'Combustível',
                                    fimIcone: Icon(Icons.arrow_drop_down_rounded, size: 22, color: textSec),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: bico.controllerPreco,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: estiloNumero,
                                decoration: campo('Preço/L (R\$)', prefixo: 'R\$ '),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Linha 2: Litros Vendidos + Total do Bico em Dinheiro
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: bico.controllerLitros,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: estiloNumero,
                                decoration: campo('Litros Vendidos', sufixo: 'L', dica: '0.00'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                  border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Total bico',
                                      style: TextStyle(color: textSec, fontSize: AppTexto.rotulo - 1, fontWeight: FontWeight.w600),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        CurrencyFormatter.formatar(bico.totalReais),
                                        style: const TextStyle(
                                          fontFamily: AppTexto.numeros,
                                          color: AppColors.green,
                                          fontWeight: FontWeight.w600,
                                          fontSize: AppTexto.corpo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),

            // Botão Adicionar Bico (se tiver mais bicos na pista)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _adicionarBico,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.accentLight),
                label: const Text(
                  'Adicionar Bico',
                  style: TextStyle(fontSize: AppTexto.corpo - 1, color: AppColors.accentLight, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── Totais Gerais ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: blocoBg,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL LITROS', style: _rotuloTotal(textSec)),
                        const SizedBox(height: 2),
                        Text(
                          '${_totalLitrosGeral.toStringAsFixed(2)} L',
                          style: TextStyle(
                            fontFamily: AppTexto.numeros,
                            color: textPri,
                            fontWeight: FontWeight.w600,
                            fontSize: AppTexto.valor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('VALOR', style: _rotuloTotal(textSec)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatar(_totalReaisGeral),
                        style: TextStyle(
                          fontFamily: AppTexto.numeros,
                          color: textPri,
                          fontWeight: FontWeight.w600,
                          fontSize: AppTexto.valor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Botões de Ação ──
            BotoesJanela(
              secundario: BotaoSecundario(texto: 'Voltar', onPressed: () => Navigator.of(context).pop()),
              principal: BotaoPrincipal(texto: 'Salvar Encerrantes', icone: Icons.check_circle_rounded, onPressed: _salvar),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle _rotuloTotal(Color cor) => TextStyle(
        fontSize: AppTexto.rotulo - 1,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: cor,
      );
}
