import 'package:flutter/material.dart';
import '../models/lancamento.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';

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

  void _salvar() {
    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
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
        title: const Text('Excluir Lançamento?'),
        content: Text(
          'Deseja realmente apagar o lançamento de ${CurrencyFormatter.formatar(widget.lancamento.valor)} em ${widget.lancamento.tipo}?',
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
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

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Editar Lançamento',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            tooltip: 'Excluir lançamento',
            onPressed: _confirmarExclusao,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controllerValor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Valor (R\$)',
                  hintText: 'R\$ 0,00',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  errorText: _erroValor,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                onChanged: (_) {
                  if (_erroValor != null) {
                    setState(() => _erroValor = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipoSelecionado,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Forma de Pagamento',
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                items: [
                  PaymentTypes.dinheiro,
                  PaymentTypes.pix,
                  ...PaymentTypes.bandeirasPadrao.map((b) => '${widget.maquinaAtiva} $b'),
                  PaymentTypes.requisicao,
                  PaymentTypes.depositoGlobal,
                  PaymentTypes.despesas,
                  PaymentTypes.sangria,
                ].toSet().map((tipo) {
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text(tipo, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _tipoSelecionado = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controllerDesc,
                decoration: InputDecoration(
                  labelText: 'Descrição / Placa (Opcional)',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: textSec)),
        ),
        ElevatedButton(
          onPressed: _salvar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
          ),
          child: const Text('Salvar Alterações', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
