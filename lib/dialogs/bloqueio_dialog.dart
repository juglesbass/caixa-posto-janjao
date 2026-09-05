import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';

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
    final bgScaffold = isDark ? const Color(0xFF090D16) : AppColors.lightBg;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final inputBg = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;

    return PopScope(
      canPop: false, // Impede fechar pelo botão voltar sem PIN
      child: Dialog.fullscreen(
        backgroundColor: bgScaffold,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2563EB), width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 54, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 20),
                Text(
                  'CAIXA BLOQUEADO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textPri,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Operador: ${widget.operador}',
                  style: TextStyle(fontSize: 14, color: textSec),
                ),
                const SizedBox(height: 30),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textPri, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'PIN',
                      hintStyle: TextStyle(color: textSec.withValues(alpha: 0.6), letterSpacing: 1),
                      errorText: _erro,
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _desbloquear(),
                  ),
                ),
                const SizedBox(height: 20),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _desbloquear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                      label: const Text(
                        'Desbloquear Caixa',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
