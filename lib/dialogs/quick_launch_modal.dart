import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../utils/currency_formatter.dart';
import '../utils/payment_types.dart';
import '../widgets/quick_amount_row.dart';

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
  String? _erroValor;

  @override
  void dispose() {
    _controllerValor.dispose();
    _controllerDesc.dispose();
    super.dispose();
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

  void _setValor(double v) {
    AppHaptics.light();
    _controllerValor.text = CurrencyFormatter.formatar(v);
    if (_erroValor != null) {
      setState(() => _erroValor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Novo Lançamento Rápido',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerValor,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [CurrencyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Valor da Venda (R\$)',
                hintText: 'R\$ 0,00',
                prefixIcon: const Icon(Icons.attach_money_rounded),
                errorText: _erroValor,
                filled: true,
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
            const SizedBox(height: 10),
            QuickAmountRow(onSelecionarValor: _setValor),
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
              ].map((tipo) {
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
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _lancar,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text('Lançar Venda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
