import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class BloqueioDialog extends StatefulWidget {
  final String operador;

  const BloqueioDialog({super.key, required this.operador});

  @override
  State<BloqueioDialog> createState() => _BloqueioDialogState();
}

class _BloqueioDialogState extends State<BloqueioDialog> {
  final _pinController = TextEditingController();
  String? _erro;

  void _desbloquear() async {
    final db = DatabaseService.instance;
    final pinSalvo = await db.getConfig('pin_acesso');
    final pinDigitado = _pinController.text.trim();

    if (pinSalvo.isEmpty || pinDigitado == pinSalvo) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _erro = 'PIN incorreto. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Impede fechar pelo botão voltar sem PIN
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF090D16),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2563EB), width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 54, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CAIXA BLOQUEADO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Operador: ${widget.operador}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 30),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'PIN',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 1),
                      errorText: _erro,
                      filled: true,
                      fillColor: const Color(0xFF131C2E),
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
                      label: const Text('Desbloquear Caixa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
