import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';

class SangriaDialog extends StatefulWidget {
  final double dinheiroNaGaveta;

  const SangriaDialog({
    super.key,
    required this.dinheiroNaGaveta,
  });

  @override
  State<SangriaDialog> createState() => _SangriaDialogState();
}

class _SangriaDialogState extends State<SangriaDialog> {
  final _controllerValor = TextEditingController();
  final _controllerMotivo = TextEditingController(text: 'Sangria para Cofre');
  String? _erroValor;

  @override
  void dispose() {
    _controllerValor.dispose();
    _controllerMotivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final valor = CurrencyFormatter.parse(_controllerValor.text);
    if (valor <= 0) {
      setState(() {
        _erroValor = 'Informe um valor maior que zero';
      });
      return;
    }

    Navigator.of(context).pop({
      'valor': valor,
      'motivo': _controllerMotivo.text.trim().isEmpty
          ? 'Sangria para Cofre'
          : _controllerMotivo.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(Icons.call_made_rounded, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Sangria para Cofre',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Disponível na Gaveta:', style: TextStyle(fontSize: 12, color: textSec)),
                  Text(
                    CurrencyFormatter.formatar(widget.dinheiroNaGaveta),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controllerValor,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [CurrencyInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Valor da Sangria (R\$)',
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
              onSubmitted: (_) => _confirmar(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerMotivo,
              decoration: InputDecoration(
                labelText: 'Motivo / Observação',
                hintText: 'Ex: Sangria periódica, excesso...',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: textSec)),
        ),
        ElevatedButton(
          onPressed: _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
          ),
          child: const Text('Confirmar Sangria', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
