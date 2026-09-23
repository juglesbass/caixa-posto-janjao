import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../widgets/janela.dart';

class CadastroPinDialog extends StatefulWidget {
  final String operador;
  final bool obrigatorio;

  const CadastroPinDialog({
    super.key,
    required this.operador,
    this.obrigatorio = true,
  });

  @override
  State<CadastroPinDialog> createState() => _CadastroPinDialogState();
}

class _CadastroPinDialogState extends State<CadastroPinDialog> {
  final _controllerPin = TextEditingController();
  final _controllerConfirma = TextEditingController();

  String? _erroPin;
  String? _erroConfirma;
  bool _salvando = false;

  @override
  void dispose() {
    _controllerPin.dispose();
    _controllerConfirma.dispose();
    super.dispose();
  }

  void _salvar() async {
    if (_salvando) return;

    final pin = _controllerPin.text.trim();
    final confirma = _controllerConfirma.text.trim();

    setState(() {
      _erroPin = null;
      _erroConfirma = null;
    });

    if (pin.length != 4 || int.tryParse(pin) == null) {
      AppHaptics.heavy();
      setState(() => _erroPin = 'O PIN deve ter exatamente 4 números');
      return;
    }

    if (confirma != pin) {
      AppHaptics.heavy();
      setState(() => _erroConfirma = 'Os PINs digitados não coincidem');
      return;
    }

    setState(() => _salvando = true);

    try {
      await AuthService.cadastrarOuAlterarPin(widget.operador, pin);
      AppHaptics.medium();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 PIN cadastrado com sucesso para ${widget.operador}!'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroPin = 'Erro ao salvar PIN: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final estiloPin = TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.w700, color: textPri);

    return PopScope(
      canPop: !widget.obrigatorio,
      child: AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        title: Column(
          children: [
            const IconeJanela(icone: Icons.shield_rounded, cor: AppColors.accentLight, tamanho: 56),
            const SizedBox(height: 12),
            Text(
              'Cadastre seu PIN de 4 dígitos',
              style: TextStyle(fontSize: AppTexto.valor + 1, fontWeight: FontWeight.w700, color: textPri),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Operador: ${widget.operador}\nEste PIN será solicitado para trancar a tela e homologar o fechamento de caixa.',
              style: TextStyle(fontSize: AppTexto.rotulo + 1, color: textSec, height: 1.35),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controllerPin,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: estiloPin,
                  decoration: InputDecoration(
                    labelText: 'Novo PIN (4 números)',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: _erroPin,
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                  ),
                  onChanged: (_) {
                    if (_erroPin != null) setState(() => _erroPin = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controllerConfirma,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: estiloPin,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Novo PIN',
                    counterText: '',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    errorText: _erroConfirma,
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                  ),
                  onChanged: (_) {
                    if (_erroConfirma != null) setState(() => _erroConfirma = null);
                  },
                  onSubmitted: (_) => _salvar(),
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: BotaoPrincipal(
              texto: _salvando ? 'Gravando PIN...' : 'Confirmar e Cadastrar PIN',
              icone: Icons.check_circle_rounded,
              ocupado: _salvando,
              onPressed: _salvando ? null : _salvar,
            ),
          ),
        ],
      ),
    );
  }
}
