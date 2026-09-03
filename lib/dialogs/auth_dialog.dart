import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dialogs/cadastro_pin_dialog.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
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

  String? _erroNome;
  String? _erroPin;
  bool _mostrarCampoPin = false;
  bool _processando = false;

  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controllerNome.dispose();
    _controllerPin.dispose();
    super.dispose();
  }

  void _onNomeChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_erroNome != null) setState(() => _erroNome = null);
      if (Validator.validarNomeOperador(val) == null) {
        final nomeFormatado = Validator.formatarNomeOperador(val);
        final temPin = await AuthService.operadorTemPin(nomeFormatado);
        if (mounted) {
          setState(() => _mostrarCampoPin = temPin);
        }
      } else {
        if (_mostrarCampoPin) setState(() => _mostrarCampoPin = false);
      }
    });
  }

  void _confirmar() async {
    if (_processando) return;

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

    final nomeFormatado = Validator.formatarNomeOperador(nomeRaw);

    setState(() {
      _processando = true;
      _erroPin = null;
    });

    // 1. Verifica se o operador já possui PIN individual cadastrado
    final temPin = await AuthService.operadorTemPin(nomeFormatado);

    if (!mounted) return;

    if (!temPin) {
      // ── FLUXO DE 1º ACESSO OBRIGATÓRIO ──
      setState(() => _processando = false);
      if (!mounted) return;

      final cadastrou = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CadastroPinDialog(
          operador: nomeFormatado,
          obrigatorio: true,
        ),
      );

      if (cadastrou != true) {
        return; // Não permite prosseguir sem cadastrar
      }
    } else {
      // ── OPERADOR JÁ TEM PIN: EXIGE DIGITAÇÃO E VALIDAÇÃO ──
      final pinDigitado = _controllerPin.text.trim();
      if (pinDigitado.isEmpty) {
        setState(() {
          _processando = false;
          _mostrarCampoPin = true;
          _erroPin = 'Digite seu PIN de 4 dígitos para acessar';
        });
        return;
      }

      final valido = await AuthService.validarPin(nomeFormatado, pinDigitado);
      if (!valido) {
        AppHaptics.heavy();
        if (mounted) {
          setState(() {
            _processando = false;
            _mostrarCampoPin = true;
            _erroPin = 'PIN incorreto. Tente novamente.';
          });
          _controllerPin.clear();
        }
        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop({
        'operador': nomeFormatado,
        'fundoCaixa': 0.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF1E293B) : AppColors.lightBorder),
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      title: Stack(
        children: [
          Center(
            child: Column(
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
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: textSec, size: 20),
              onPressed: () => Navigator.of(context).pop(),
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
                onChanged: _onNomeChanged,
                onSubmitted: (_) => _confirmar(),
              ),
              if (_mostrarCampoPin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _controllerPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                    color: textPri,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PIN de acesso (4 números)',
                    counterText: '',
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _processando ? null : _confirmar,
                icon: Icon(
                  widget.novoTurno ? Icons.play_arrow_rounded : Icons.login_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  _processando
                      ? 'Autenticando...'
                      : (widget.novoTurno ? 'Abrir Turno Agora' : 'Entrar'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (widget.novoTurno) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop({'acao': 'historico'}),
                  icon: const Icon(Icons.history_rounded, size: 18, color: Color(0xFF06B6D4)),
                  label: const Text(
                    'Histórico e Reabrir Turno',
                    style: TextStyle(
                      color: Color(0xFF06B6D4),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF06B6D4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Exibe modal de bloqueio administrativo solicitando o PIN Mestre da Gerência
  static Future<bool> solicitarPinGerente(
    BuildContext context, {
    String titulo = 'Acesso Restrito da Gerência',
    String subtitulo = 'Digite o PIN Mestre Administrativo de 4 dígitos para liberar o acesso:',
  }) async {
    final controllerPin = TextEditingController();
    String? erro;
    bool validando = false;

    final bool? autorizado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
            final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPri,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12.5, color: textSec),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controllerPin,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 22,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: erro,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Cancelar', style: TextStyle(color: textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: validando
                      ? null
                      : () async {
                          final p = controllerPin.text.trim();
                          if (p.length != 4) {
                            setModalState(() => erro = 'Digite os 4 dígitos');
                            return;
                          }
                          setModalState(() => validando = true);
                          final ok = await AuthService.validarPinGerente(p);
                          if (!ok) {
                            setModalState(() {
                              validando = false;
                              erro = 'PIN Mestre Incorreto!';
                            });
                            controllerPin.clear();
                            return;
                          }
                          Navigator.of(ctx).pop(true);
                        },
                  child: const Text('Desbloquear', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    controllerPin.dispose();
    return autorizado == true;
  }
}
