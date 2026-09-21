import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/campos_lancamento.dart';
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
  String _tipoSelecionado = PaymentTypes.dinheiro;
  String _bandeira = 'Master Débito';
  double _valor = 0.0;
  String? _erroValor;

  @override
  void dispose() {
    _controllerValor.dispose();
    _controllerDesc.dispose();
    super.dispose();
  }

  void _selecionarTipo(String tipo) {
    setState(() => _tipoSelecionado = tipo);
  }

  /// Cartões abre a escolha de bandeira, como na tela Início. A máquina é a
  /// que está ativa — a mesma que a lista antiga usava.
  Future<void> _abrirSeletorCartoes() async {
    final escolhida = await showDialog<String>(
      context: context,
      builder: (ctx) => CardBrandDialog(
        maquinaAtiva: widget.maquinaAtiva,
        bandeiraSelecionada: _bandeira,
      ),
    );
    if (escolhida == null || !mounted) return;
    AppHaptics.light();
    setState(() {
      _bandeira = escolhida;
      _tipoSelecionado = '${widget.maquinaAtiva} $escolhida';
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

  void _lancar() {
    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      AppHaptics.heavy();
      setState(() => _erroValor = 'Informe um valor maior que zero');
      return;
    }

    AppHaptics.light();
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

    // Mesma margem lateral da tela Início (14), para os cartões e o conteúdo
    // deles caírem nas mesmas linhas das duas telas.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                      // Cartão cai na máquina ativa; melhor dizer antes de lançar.
                      Text(
                        'Cartões na máquina ${widget.maquinaAtiva}',
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
            const SizedBox(height: 12),
            PaymentGrid(
              tipoAtivo: _tipoSelecionado,
              bandeiraCartaoAtiva: _bandeira,
              onSelecionarTipo: _selecionarTipo,
              onAbrirSeletorCartoes: _abrirSeletorCartoes,
            ),
            const SizedBox(height: 14),
            CampoValorVenda(
              controller: _controllerValor,
              autofocus: true,
              podeLancar: _valor > 0,
              erro: _erroValor,
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
    );
  }
}
