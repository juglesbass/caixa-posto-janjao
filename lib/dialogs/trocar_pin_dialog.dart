import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class TrocarPinDialog extends StatefulWidget {
  final String operador;

  const TrocarPinDialog({super.key, required this.operador});

  @override
  State<TrocarPinDialog> createState() => _TrocarPinDialogState();
}

class _TrocarPinDialogState extends State<TrocarPinDialog> {
  final _controllerAtual = TextEditingController();
  final _controllerNovo = TextEditingController();
  final _controllerConfirma = TextEditingController();

  String? _erroAtual;
  String? _erroNovo;
  String? _erroConfirma;
  bool _salvando = false;

  @override
  void dispose() {
    _controllerAtual.dispose();
    _controllerNovo.dispose();
    _controllerConfirma.dispose();
    super.dispose();
  }

  void _confirmarTroca() async {
    if (_salvando) return;

    final atual = _controllerAtual.text.trim();
    final novo = _controllerNovo.text.trim();
    final confirma = _controllerConfirma.text.trim();

    setState(() {
      _erroAtual = null;
      _erroNovo = null;
      _erroConfirma = null;
    });

    final atualValido = await AuthService.validarPin(widget.operador, atual);
    if (!mounted) return;
    if (!atualValido) {
      HapticFeedback.heavyImpact();
      setState(() => _erroAtual = 'PIN atual incorreto (ou PIN do Gerente)');
      return;
    }

    if (novo.length != 4 || int.tryParse(novo) == null) {
      HapticFeedback.heavyImpact();
      setState(() => _erroNovo = 'O novo PIN deve ter 4 dígitos');
      return;
    }

    if (confirma != novo) {
      HapticFeedback.heavyImpact();
      setState(() => _erroConfirma = 'A confirmação não confere com o novo PIN');
      return;
    }

    setState(() => _salvando = true);

    try {
      await AuthService.cadastrarOuAlterarPin(widget.operador, novo);
      HapticFeedback.mediumImpact();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PIN de ${widget.operador} alterado com sucesso!'),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erroNovo = 'Erro ao salvar novo PIN: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgScaffold = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderColor = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return AlertDialog(
      backgroundColor: bgScaffold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(Icons.password_rounded, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alterar PIN de Segurança',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                ),
                Text(
                  'Operador: ${widget.operador}',
                  style: TextStyle(fontSize: 11, color: textSec),
                ),
              ],
            ),
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
                controller: _controllerAtual,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: textPri),
                decoration: InputDecoration(
                  labelText: 'PIN Atual (ou PIN do Gerente)',
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  errorText: _erroAtual,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
                onChanged: (_) {
                  if (_erroAtual != null) setState(() => _erroAtual = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controllerNovo,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: textPri),
                decoration: InputDecoration(
                  labelText: 'Novo PIN (4 dígitos)',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_rounded),
                  errorText: _erroNovo,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
                onChanged: (_) {
                  if (_erroNovo != null) setState(() => _erroNovo = null);
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
                style: TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold, color: textPri),
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
                onSubmitted: (_) => _confirmarTroca(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: textSec)),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _confirmarTroca,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _salvando ? 'Salvando...' : 'Salvar Novo PIN',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
