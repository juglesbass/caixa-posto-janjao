import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../widgets/janela.dart';

class BloqueioDialog extends StatefulWidget {
  final String operador;

  const BloqueioDialog({super.key, required this.operador});

  @override
  State<BloqueioDialog> createState() => _BloqueioDialogState();
}

class _BloqueioDialogState extends State<BloqueioDialog> {
  final _pinController = TextEditingController();
  String? _erro;
  bool _validando = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _desbloquear() async {
    if (_validando) return;
    final pinDigitado = _pinController.text.trim();

    if (pinDigitado.isEmpty) {
      setState(() => _erro = 'Informe o PIN de 4 dígitos');
      return;
    }

    setState(() {
      _validando = true;
      _erro = null;
    });

    final valido = await AuthService.validarPin(widget.operador, pinDigitado);

    if (valido) {
      AppHaptics.medium();
      if (mounted) Navigator.of(context).pop(true);
    } else {
      AppHaptics.heavy();
      if (mounted) {
        setState(() {
          _validando = false;
          _erro = 'PIN Incorreto. Acesso Negado!';
        });
        _pinController.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgScaffold = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final inputBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return PopScope(
      canPop: false, // Impede fechar pelo botão voltar sem PIN
      child: Dialog.fullscreen(
        backgroundColor: bgScaffold,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: IconeJanela(icone: Icons.lock_rounded, cor: AppColors.accentLight, tamanho: 80)),
                    const SizedBox(height: 20),
                    Text(
                      'Caixa bloqueado',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppTexto.entrada, fontWeight: FontWeight.w800, color: textPri),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Operador: ${widget.operador}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppTexto.corpo, color: textSec),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textPri, fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: 'PIN',
                        hintStyle: TextStyle(color: textSec.withValues(alpha: 0.6), letterSpacing: 1, fontSize: AppTexto.valor),
                        errorText: _erro,
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
                      ),
                      onSubmitted: (_) => _desbloquear(),
                    ),
                    const SizedBox(height: 16),
                    BotaoPrincipal(
                      texto: 'Desbloquear Caixa',
                      icone: Icons.lock_open_rounded,
                      ocupado: _validando,
                      onPressed: _desbloquear,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
