import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/campos_lancamento.dart';
import '../widgets/machine_selector.dart';
import '../widgets/payment_grid.dart';
import '../widgets/quick_amount_row.dart';
import 'card_brand_dialog.dart';

/// Lançamento rápido do "+" do rodapé: lança de qualquer aba sem ir até a
/// tela Início.
///
/// Usa as mesmas peças da Início — a grade de formas com ícones, o campo de
/// valor com o Lançar colado, os valores rápidos — para quem aprendeu uma tela
/// já saber usar a outra. Antes a forma de pagamento era uma lista corrida de
/// umas vinte opções sem ícone, com todas as bandeiras misturadas.
///
/// A grade vem antes do valor: com o teclado aberto, forma de pagamento, valor
/// e o botão Lançar ficam todos acima dele.
class QuickLaunchModal extends StatefulWidget {
  final String maquinaAtiva;
  final ValueChanged<({String tipo, double valor, String descricao})> onLancar;

  const QuickLaunchModal({
    super.key,
    required this.maquinaAtiva,
    required this.onLancar,
  });

  @override
  State<QuickLaunchModal> createState() => _QuickLaunchModalState();
}

class _QuickLaunchModalState extends State<QuickLaunchModal> {
  final _controllerValor = TextEditingController();
  final _controllerDesc = TextEditingController();
  late String _maquinaAtiva;
  String _tipoSelecionado = PaymentTypes.dinheiro;
  String _bandeira = 'Master Débito';
  double _valor = 0.0;
  String? _erroValor;
  bool _lancando = false;

  @override
  void initState() {
    super.initState();
    _maquinaAtiva = widget.maquinaAtiva;
  }

  @override
  void dispose() {
    _controllerValor.dispose();
    _controllerDesc.dispose();
    super.dispose();
  }

  void _selecionarTipo(String tipo) {
    setState(() => _tipoSelecionado = tipo);
  }

  Future<void> _selecionarMaquina(String maq) async {
    setState(() {
      _maquinaAtiva = maq;
      if (PaymentTypes.ehCartao(_tipoSelecionado)) {
        _tipoSelecionado = '$_maquinaAtiva $_bandeira';
      }
    });
    await PaymentTypes.definirMaquinaAtiva(maq);
  }

  /// Cartões abre a escolha de bandeira, como na tela Início.
  Future<void> _abrirSeletorCartoes() async {
    final escolhida = await showDialog<String>(
      context: context,
      builder: (ctx) => CardBrandDialog(
        maquinaAtiva: _maquinaAtiva,
        bandeiraSelecionada: _bandeira,
      ),
    );
    if (escolhida == null || !mounted) return;
    AppHaptics.light();
    setState(() {
      _bandeira = escolhida;
      _tipoSelecionado = '$_maquinaAtiva $escolhida';
    });
  }

  /// Os atalhos somam ao valor digitado, como na tela Início e como o "+" do
  /// botão promete. Antes, aqui, eles substituíam o valor.
  void _somarValor(double v) {
    AppHaptics.light();
    final novo = _valor + v;
    _controllerValor.text = CurrencyFormatter.formatar(novo);
    setState(() {
      _valor = novo;
      _erroValor = null;
    });
  }

  void _limparValor() {
    AppHaptics.light();
    _controllerValor.clear();
    setState(() {
      _valor = 0.0;
      _erroValor = null;
    });
  }

  void _lancar() {
    if (_lancando) return;
    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      AppHaptics.heavy();
      setState(() => _erroValor = 'Informe um valor maior que zero');
      return;
    }

    _lancando = true;
    AppHaptics.light();
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
    widget.onLancar((
      tipo: _tipoSelecionado,
      valor: valor,
      descricao: _controllerDesc.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;

    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxModalHeight = MediaQuery.sizeOf(context).height * 0.92;

    // Mesma margem lateral da tela Início (14), para os cartões e o conteúdo
    // deles caírem nas mesmas linhas das duas telas.
    return SafeArea(
      top: true,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxModalHeight),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: viewInsetsBottom + 16,
            top: 8,
            left: 14,
            right: 14,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Alça: diz que a folha pode ser arrastada para baixo para fechar.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: textTer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lançamento rápido',
                            style: TextStyle(
                              fontSize: AppTexto.valor,
                              fontWeight: FontWeight.w700,
                              color: textPri,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cartões na máquina $_maquinaAtiva',
                            style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MachineSelector(
                  maquinaAtiva: _maquinaAtiva,
                  onSelecionar: _selecionarMaquina,
                ),
                const SizedBox(height: 10),
                PaymentGrid(
                  tipoAtivo: _tipoSelecionado,
                  bandeiraCartaoAtiva: _bandeira,
                  onSelecionarTipo: _selecionarTipo,
                  onAbrirSeletorCartoes: _abrirSeletorCartoes,
                  compacto: true,
                ),
                const SizedBox(height: 14),
                CampoValorVenda(
                  controller: _controllerValor,
                  autofocus: !kIsWeb,
                  podeLancar: _valor > 0,
                  erro: _erroValor,
                  onLimpar: _valor > 0 ? _limparValor : null,
                  onChanged: (val) {
                    setState(() {
                      _valor = CurrencyFormatter.parse(val);
                      if (_erroValor != null) _erroValor = null;
                    });
                  },
                  onLancar: _lancar,
                ),
                const SizedBox(height: 12),
                QuickAmountRow(onSelecionarValor: _somarValor),
                const SizedBox(height: 12),
                CampoDescricao(controller: _controllerDesc, onSubmitted: _lancar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
