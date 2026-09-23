import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import '../widgets/janela.dart';

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
      AppHaptics.heavy();
      setState(() => _erroAtual = 'PIN atual incorreto (ou PIN do Desenvolvedor)');
      return;
    }

    if (novo.length != 4 || int.tryParse(novo) == null) {
      AppHaptics.heavy();
      setState(() => _erroNovo = 'O novo PIN deve ter 4 dígitos');
      return;
    }

    if (confirma != novo) {
      AppHaptics.heavy();
      setState(() => _erroConfirma = 'A confirmação não confere com o novo PIN');
      return;
    }

    setState(() => _salvando = true);

    try {
      await AuthService.cadastrarOuAlterarPin(widget.operador, novo);
      AppHaptics.medium();

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
    final estiloPin = TextStyle(
      fontSize: 20,
      letterSpacing: 8,
      fontWeight: FontWeight.w700,
      color: isDark ? AppColors.darkTextPri : AppColors.lightTextPri,
    );

    return AlertDialog(
      title: CabecalhoJanela(
        icone: Icons.password_rounded,
        cor: AppColors.accentLight,
        titulo: 'Alterar PIN de Segurança',
        subtitulo: 'Operador: ${widget.operador}',
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
                style: estiloPin,
                decoration: InputDecoration(
                  labelText: 'PIN Atual (ou PIN do Desenvolvedor)',
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
                style: estiloPin,
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
                onSubmitted: (_) => _confirmarTroca(),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        BotoesJanela(
          secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(context).pop(false)),
          principal: BotaoPrincipal(
            texto: _salvando ? 'Salvando...' : 'Salvar Novo PIN',
            ocupado: _salvando,
            onPressed: _salvando ? null : _confirmarTroca,
          ),
        ),
      ],
    );
  }
}
