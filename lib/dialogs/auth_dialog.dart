import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../utils/validator.dart';

class AuthDialog extends StatefulWidget {
  final bool novoTurno;
  final String? pinConfigurado;

  const AuthDialog({
    super.key,
    required this.novoTurno,
    this.pinConfigurado,
  });

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final _controllerNome = TextEditingController();
  final _controllerPin = TextEditingController();
  final _controllerFundo = TextEditingController();

  String? _erroNome;
  String? _erroPin;

  @override
  void dispose() {
    _controllerNome.dispose();
    _controllerPin.dispose();
    _controllerFundo.dispose();
    super.dispose();
  }

  void _confirmar() async {
    final nomeRaw = _controllerNome.text;
    final erroValidacao = Validator.validarNomeOperador(nomeRaw);

    if (erroValidacao != null) {
      setState(() {
        _erroNome = erroValidacao;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erroValidacao),
          backgroundColor: AppColors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final temPin = widget.pinConfigurado != null &&
        widget.pinConfigurado!.isNotEmpty &&
        !widget.novoTurno;

    if (temPin && _controllerPin.text != widget.pinConfigurado) {
      setState(() {
        _erroPin = 'PIN incorreto';
      });
      return;
    }

    final nomeFormatado = Validator.formatarNomeOperador(nomeRaw);
    final fundo = CurrencyFormatter.parse(_controllerFundo.text);

    Navigator.of(context).pop({
      'operador': nomeFormatado,
      'fundoCaixa': fundo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final temPin = widget.pinConfigurado != null &&
        widget.pinConfigurado!.isNotEmpty &&
        !widget.novoTurno;

    return AlertDialog(
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.novoTurno
                  ? Icons.local_gas_station_rounded
                  : Icons.waving_hand_rounded,
              color: AppColors.accentLight,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.novoTurno ? 'Abrir Novo Turno' : 'Bem-vindo(a) de volta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPri,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.novoTurno
                ? 'Informe seu nome para começar o turno.'
                : 'Informe seu nome para continuar de onde parou.',
            style: TextStyle(fontSize: 12, color: textSec),
            textAlign: TextAlign.center,
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
                controller: _controllerNome,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Seu nome',
                  hintText: 'Como podemos te chamar?',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _erroNome,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                onChanged: (_) {
                  if (_erroNome != null) {
                    setState(() => _erroNome = null);
                  }
                },
                onSubmitted: (_) => _confirmar(),
              ),
              if (widget.novoTurno) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _controllerFundo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Fundo de Caixa / Troco Inicial',
                    hintText: 'R\$ 0,00 (Opcional)',
                    prefixIcon: const Icon(Icons.savings_outlined),
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  onSubmitted: (_) => _confirmar(),
                ),
              ],
              if (temPin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _controllerPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN de acesso',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: _erroPin,
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  onChanged: (_) {
                    if (_erroPin != null) {
                      setState(() => _erroPin = null);
                    }
                  },
                  onSubmitted: (_) => _confirmar(),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: 240,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _confirmar,
            icon: Icon(
              widget.novoTurno ? Icons.play_arrow_rounded : Icons.login_rounded,
              color: Colors.white,
            ),
            label: Text(
              widget.novoTurno ? 'Abrir Turno' : 'Entrar',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
