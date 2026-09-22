import 'package:flutter/material.dart';
import '../models/lancamento.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/campos_lancamento.dart';
import '../widgets/payment_grid.dart';
import 'card_brand_dialog.dart';

/// Corrigir um lançamento: valor, forma de pagamento e descrição — ou excluir.
///
/// Abre ao tocar num lançamento (tela Início e Histórico). Usa as mesmas peças
/// de quem lança — grade de formas com ícones, campo de valor, descrição —
/// para corrigir ter a mesma cara de lançar.
///
/// As opções de destino são as mesmas de antes: as formas da grade, as
/// bandeiras da máquina ativa e o tipo atual do lançamento. Um tipo que não
/// está na grade (Sangria, de turno antigo) continua como está a menos que se
/// escolha outro — só não dá para transformar um lançamento em sangria.
class EditLaunchDialog extends StatefulWidget {
  final Lancamento lancamento;
  final String maquinaAtiva;
  final ValueChanged<({String tipo, double valor, String descricao})> onSalvar;
  final VoidCallback onDeletar;

  const EditLaunchDialog({
    super.key,
    required this.lancamento,
    required this.maquinaAtiva,
    required this.onSalvar,
    required this.onDeletar,
  });

  @override
  State<EditLaunchDialog> createState() => _EditLaunchDialogState();
}

class _EditLaunchDialogState extends State<EditLaunchDialog> {
  late TextEditingController _controllerValor;
  late TextEditingController _controllerDesc;
  late String _tipoSelecionado;
  String? _erroValor;

  static const _maquinas = [PaymentTypes.maquinaRede, PaymentTypes.maquinaCielo, 'Stone', 'PagBank'];

  @override
  void initState() {
    super.initState();
    _controllerValor = TextEditingController(
      text: CurrencyFormatter.formatar(widget.lancamento.valor),
    );
    _controllerDesc = TextEditingController(text: widget.lancamento.descricao);
    _tipoSelecionado = widget.lancamento.tipo;
  }

  @override
  void dispose() {
    _controllerValor.dispose();
    _controllerDesc.dispose();
    super.dispose();
  }

  /// "Cielo VR Multibenefícios" → "VR Multibenefícios".
  static String _bandeiraDe(String tipo) {
    final partes = tipo.trim().split(' ');
    if (partes.length > 1 && _maquinas.contains(partes.first)) {
      return partes.skip(1).join(' ');
    }
    return tipo;
  }

  /// O tipo aparece selecionado na grade? Os que não aparecem são tipos antigos.
  static bool _estaNaGrade(String tipo) =>
      tipo == PaymentTypes.dinheiro ||
      tipo == PaymentTypes.pix ||
      tipo == PaymentTypes.requisicao ||
      tipo == PaymentTypes.depositoGlobal ||
      tipo == PaymentTypes.despesas ||
      PaymentTypes.ehCartao(tipo);

  Future<void> _escolherBandeira() async {
    final atual = _tipoSelecionado.startsWith('${widget.maquinaAtiva} ')
        ? _bandeiraDe(_tipoSelecionado)
        : '';
    final escolhida = await showDialog<String>(
      context: context,
      builder: (ctx) => CardBrandDialog(
        maquinaAtiva: widget.maquinaAtiva,
        bandeiraSelecionada: atual,
      ),
    );
    if (escolhida == null || !mounted) return;
    setState(() => _tipoSelecionado = '${widget.maquinaAtiva} $escolhida');
  }

  void _salvar() {
    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      AppHaptics.heavy();
      setState(() => _erroValor = 'Informe um valor maior que zero');
      return;
    }

    Navigator.of(context).pop();
    widget.onSalvar((
      tipo: _tipoSelecionado,
      valor: valor,
      descricao: _controllerDesc.text.trim(),
    ));
  }

  void _confirmarExclusao() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text(
          'O lançamento de ${CurrencyFormatter.formatar(widget.lancamento.valor)} em '
          '${widget.lancamento.tipo} será apagado do turno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              widget.onDeletar();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, elevation: 0),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final l = widget.lancamento;
    final hora = l.hora.length >= 5 ? l.hora.substring(0, 5) : l.hora;
    final tipoAntigo = !_estaNaGrade(_tipoSelecionado);

    return Dialog(
      // Margem lateral estreita: a grade de formas precisa da largura.
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Corrigir lançamento',
                          style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                        ),
                        const SizedBox(height: 2),
                        // O que foi lançado, para conferir antes de mudar.
                        Text(
                          '$hora · ${CurrencyFormatter.formatar(l.valor)} em ${l.tipo}',
                          style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                    tooltip: 'Excluir lançamento',
                    onPressed: _confirmarExclusao,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tipoAntigo) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: isDark ? 0.12 : 0.10),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Forma atual: $_tipoSelecionado. Continua assim se você não escolher outra.',
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textPri, height: 1.3),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              PaymentGrid(
                tipoAtivo: _tipoSelecionado,
                bandeiraCartaoAtiva:
                    PaymentTypes.ehCartao(_tipoSelecionado) ? _bandeiraDe(_tipoSelecionado) : 'Master Débito',
                onSelecionarTipo: (t) => setState(() => _tipoSelecionado = t),
                onAbrirSeletorCartoes: _escolherBandeira,
                compacto: true,
              ),
              const SizedBox(height: 14),
              CampoValorVenda(
                controller: _controllerValor,
                rotulo: 'Valor',
                // Sem o Lançar colado: aqui quem confirma é o Salvar, embaixo.
                podeLancar: false,
                erro: _erroValor,
                onChanged: (_) {
                  if (_erroValor != null) setState(() => _erroValor = null);
                },
                onLancar: _salvar,
              ),
              const SizedBox(height: 12),
              CampoDescricao(controller: _controllerDesc, onSubmitted: _salvar),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text('Cancelar', style: TextStyle(color: textSec, fontSize: AppTexto.corpo)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _salvar,
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Salvar correção',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: AppTexto.corpo),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
