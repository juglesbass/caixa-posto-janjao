import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../dialogs/analytics_dialog.dart';
import '../dialogs/bloqueio_dialog.dart';
import '../dialogs/encerrantes_dialog.dart';
import '../dialogs/reset_dialog.dart';
import '../dialogs/sangria_dialog.dart';
import '../dialogs/trocar_pin_dialog.dart';
import '../dialogs/turnos_anteriores_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_haptics.dart';
import 'consulta_produtos_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Turno? turno;
  final TotaisTurno totais;
  final bool isDark;
  final ValueChanged<bool> onMudarTema;
  final VoidCallback onAbrirNovoTurno;
  final VoidCallback onAbrirResumo;
  final VoidCallback onRecarregar;
  final VoidCallback? onFechar;

  const SettingsScreen({
    super.key,
    required this.turno,
    required this.totais,
    required this.isDark,
    required this.onMudarTema,
    required this.onAbrirNovoTurno,
    required this.onAbrirResumo,
    required this.onRecarregar,
    this.onFechar,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _adminLiberado = false;
  final _controllerPinMestre = TextEditingController();
  String? _erroPinMestre;
  bool _validandoPinMestre = false;

  @override
  void dispose() {
    _controllerPinMestre.dispose();
    super.dispose();
  }

  void _abrirConsultaProdutos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const ConsultaProdutosScreen()),
    );
  }

  void _abrirEncerrantes(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => EncerrantesDialog(turnoId: widget.turno!.id!),
    );
  }

  void _abrirSangria(BuildContext context) async {
    if (widget.turno == null) return;
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SangriaDialog(dinheiroNaGaveta: widget.totais.dinheiroGaveta),
    );

    if (res != null) {
      final db = DatabaseService.instance;
      await db.inserirLancamento(
        widget.turno!.id!,
        'Sangria',
        res['valor'] as double,
        res['motivo'] as String,
      );
      widget.onRecarregar();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sangria registrada com sucesso!'),
            backgroundColor: AppColors.orange,
          ),
        );
      }
    }
  }

  void _abrirAnalytics(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AnalyticsDialog(turno: widget.turno!, totais: widget.totais),
    );
  }

  void _exportarCsv(BuildContext context) async {
    if (widget.turno == null) return;
    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(widget.turno!.id!);
      await CsvService.exportarECompartilharCsv(
        turno: widget.turno!,
        totais: widget.totais,
        lancamentos: lancamentos,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar CSV: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _sincronizarDrive(BuildContext context) async {
    try {
      final res = await DriveService.sincronizarTodasPendencias();
      widget.onRecarregar();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.mensagem),
            backgroundColor: res.todosOk ? AppColors.green : AppColors.amber,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na sincronização: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _bloquearCaixa(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BloqueioDialog(operador: widget.turno!.operador),
    );
  }

  void _abrirTrocarPin(BuildContext context) {
    if (widget.turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => TrocarPinDialog(operador: widget.turno!.operador),
    );
  }

  void _abrirHistoricoTurnos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => TurnosAnterioresDialog(
        onReabrirTurno: (turnoReaberto) async {
          final db = DatabaseService.instance;
          await db.reabrirTurno(turnoReaberto.id!);
          widget.onRecarregar();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔓 Turno #${turnoReaberto.numero} reaberto com sucesso!'),
                backgroundColor: AppColors.green,
              ),
            );
          }
        },
      ),
    );
  }

  void _limparZerarTudo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ResetDialog(
        onResetConcluido: () {
          widget.onRecarregar();
          widget.onAbrirNovoTurno();
        },
      ),
    );
  }

  Future<void> _desbloquearComPinMestre() async {
    final p = _controllerPinMestre.text.trim();
    if (p.length != 4) {
      setState(() => _erroPinMestre = 'Informe os 4 dígitos do PIN');
      return;
    }
    setState(() {
      _validandoPinMestre = true;
      _erroPinMestre = null;
    });
    final ok = await AuthService.validarPinGerente(p);
    if (!mounted) return;
    if (!ok) {
      AppHaptics.heavy();
      setState(() {
        _validandoPinMestre = false;
        _erroPinMestre = 'PIN Mestre Incorreto!';
      });
      _controllerPinMestre.clear();
      return;
    }
    AppHaptics.light();
    setState(() {
      _validandoPinMestre = false;
      _adminLiberado = true;
    });
  }

  Future<void> _abrirAlterarPinMestre(BuildContext context) async {
    final controllerNovoPin = TextEditingController();
    final controllerConfirmaPin = TextEditingController();
    String? erro;

    final bool? alterou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.key_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Alterar PIN Mestre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPri)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Defina um novo PIN Mestre de 4 dígitos para a gerência (armazenado com hash SHA-256):', style: TextStyle(fontSize: 12.5, color: textSec)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controllerNovoPin,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w900, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Novo PIN (4 dígitos)',
                      hintText: '••••',
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controllerConfirmaPin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w900, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Novo PIN',
                      hintText: '••••',
                      counterText: '',
                      errorText: erro,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                  onPressed: () async {
                    final p1 = controllerNovoPin.text.trim();
                    final p2 = controllerConfirmaPin.text.trim();
                    if (p1.length != 4 || p2.length != 4) {
                      setModalState(() => erro = 'Ambos devem ter 4 dígitos');
                      return;
                    }
                    if (p1 != p2) {
                      setModalState(() => erro = 'Os PINs não conferem!');
                      return;
                    }
                    await AuthService.alterarPinGerente(p1);
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Salvar PIN Mestre', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    controllerNovoPin.dispose();
    controllerConfirmaPin.dispose();

    if (alterou == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PIN Mestre da Gerência atualizado com sucesso!'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Future<void> _abrirGestaoOperadores(BuildContext context) async {
    final operadores = await AuthService.obterOperadoresComPin();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF111420) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Color(0xFF0284C7), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestão de Operadores & Senhas',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPri),
                              ),
                              Text(
                                'Redefina ou limpe senhas de operadores',
                                style: TextStyle(fontSize: 12, color: textSec),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (operadores.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.person_off_rounded, size: 40, color: textSec.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            Text('Nenhum operador com PIN cadastrado ainda.', style: TextStyle(color: textSec, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: operadores.length,
                          separatorBuilder: (_, __) => const Divider(height: 12),
                          itemBuilder: (context, idx) {
                            final op = operadores[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF0284C7).withOpacity(0.2),
                                child: Text(
                                  op.isNotEmpty ? op[0] : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                              title: Text(op, style: TextStyle(fontWeight: FontWeight.bold, color: textPri, fontSize: 14)),
                              subtitle: Text('PIN Protegido • Homologado', style: TextStyle(fontSize: 11.5, color: textSec)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 20),
                                    tooltip: 'Redefinir PIN',
                                    onPressed: () async {
                                      Navigator.of(ctx).pop();
                                      await _dialogRedefinirPinEspecifico(context, op);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                    tooltip: 'Excluir PIN',
                                    onPressed: () async {
                                      await AuthService.excluirPinOperador(op);
                                      operadores.remove(op);
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _dialogRedefinirPinEspecifico(BuildContext context, String operador) async {
    final controller = TextEditingController();
    String? erro;
    final isDark = widget.isDark;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Redefinir PIN de $operador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textPri)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Digite o novo PIN de 4 dígitos para este operador:', style: TextStyle(fontSize: 12.5, color: textSec)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 22, letterSpacing: 10, fontWeight: FontWeight.w900, color: textPri),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: erro,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
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
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final p = controller.text.trim();
                    if (p.length != 4) {
                      setModalState(() => erro = 'Digite 4 dígitos');
                      return;
                    }
                    await AuthService.redefinirPinOperador(operador, p);
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Salvar PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PIN de $operador redefinido com sucesso!'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  Widget _construirTelaBloqueio(BuildContext context) {
    final isDark = widget.isDark;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final bgScaffold = isDark ? const Color(0xFF090D16) : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111420) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Color(0xFFF59E0B),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Área Restrita da Gerência',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Digite o PIN Mestre Administrativo de 4 dígitos para ter acesso às configurações restritas do posto:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSec,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controllerPinMestre,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 26,
                      letterSpacing: 12,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: _erroPinMestre,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (_) => _desbloquearComPinMestre(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: _validandoPinMestre
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.lock_open_rounded, size: 20),
                      label: Text(
                        _validandoPinMestre ? 'Verificando...' : 'Liberar Configurações',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _validandoPinMestre ? null : _desbloquearComPinMestre,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      if (widget.onFechar != null) {
                        widget.onFechar!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                    child: Text(
                      'Voltar ao Caixa',
                      style: TextStyle(color: textSec, fontSize: 13, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    if (!_adminLiberado) {
      return _construirTelaBloqueio(context);
    }

    final isDark = widget.isDark;
    final bgScaffold = isDark ? const Color(0xFF090D16) : AppColors.lightBg;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF64748B) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra Superior com Ícone de Sliders e Fechar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Painel da Gerência',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPri,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Configurações administrativas e segurança',
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B)),
                    tooltip: 'Bloquear Painel',
                    onPressed: () {
                      AppHaptics.light();
                      setState(() {
                        _adminLiberado = false;
                        _controllerPinMestre.clear();
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSec),
                    onPressed: () {
                      if (widget.onFechar != null) {
                        widget.onFechar!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderCol),

            // ── Lista de Opções do Menu ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  // ── GESTÃO ADMINISTRATIVA E PIN MESTRE ──
                  _itemMenuCard(
                    icon: Icons.key_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Alterar PIN Mestre da Gerência',
                    subtitulo: 'Modificar a senha administrativa mestre (SHA-256)',
                    onTap: () => _abrirAlterarPinMestre(context),
                  ),
                  const SizedBox(height: 8),

                  _itemMenuCard(
                    icon: Icons.badge_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0369A1).withOpacity(0.4),
                    titulo: 'Gestão de Operadores & Senhas',
                    subtitulo: 'Visualizar operadores cadastrados e redefinir PINs',
                    onTap: () => _abrirGestaoOperadores(context),
                  ),
                  const SizedBox(height: 8),

                  // 1. Tabela de Códigos / Produtos (Novo)
                  _itemMenuCard(
                    icon: Icons.shopping_bag_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0C4A6E).withOpacity(0.4),
                    titulo: 'Tabela de Códigos / Produtos',
                    subtitulo: 'Consulta rápida por código ou nome do produto',
                    onTap: () => _abrirConsultaProdutos(context),
                  ),
                  const SizedBox(height: 8),

                  // 2. Encerrantes de Bombas
                  _itemMenuCard(
                    icon: Icons.local_gas_station_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Encerrantes de Bombas',
                    subtitulo: 'Conferência de litros vendidos nos bicos',
                    onTap: () => _abrirEncerrantes(context),
                  ),
                  const SizedBox(height: 8),

                  // 3. Sangria de Caixa
                  _itemMenuCard(
                    icon: Icons.north_east_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFF7C2D12).withOpacity(0.4),
                    titulo: 'Sangria de Caixa',
                    subtitulo: 'Registrar retirada de dinheiro para o cofre',
                    onTap: () => _abrirSangria(context),
                  ),
                  const SizedBox(height: 8),

                  // 4. Analytics & Desempenho
                  _itemMenuCard(
                    icon: Icons.auto_graph_rounded,
                    iconColor: const Color(0xFFA855F7),
                    iconBg: const Color(0xFF581C87).withOpacity(0.4),
                    titulo: 'Analytics & Desempenho',
                    subtitulo: 'Gráficos de vendas, ticket médio e formas',
                    onTap: () => _abrirAnalytics(context),
                  ),
                  const SizedBox(height: 8),

                  // 5. Exportar Planilha Excel (CSV)
                  _itemMenuCard(
                    icon: Icons.table_chart_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFF064E3B).withOpacity(0.4),
                    titulo: 'Exportar Planilha Excel (CSV)',
                    subtitulo: 'Salvar ou compartilhar dados estruturados',
                    onTap: () => _exportarCsv(context),
                  ),
                  const SizedBox(height: 8),

                  // 6. Sincronizar com Google Drive
                  _itemMenuCard(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0C4A6E).withOpacity(0.4),
                    titulo: 'Sincronizar com Google Drive',
                    subtitulo: 'Forçar reenvio de relatórios pendentes na fila',
                    onTap: () => _sincronizarDrive(context),
                  ),
                  const SizedBox(height: 8),

                  // 7. Modo Teste / Simulação (Drive)
                  ValueListenableBuilder<bool>(
                    valueListenable: DriveService.modoTesteNotifier,
                    builder: (context, modoTeste, _) {
                      return _itemMenuSwitch(
                        icon: Icons.science_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        iconBg: const Color(0xFF78350F).withOpacity(0.4),
                        titulo: 'Modo Teste / Simulação',
                        subtitulo: 'Envia os relatórios para a pasta de homologação no Drive',
                        valor: modoTeste,
                        onChanged: (novoValor) async {
                          await DriveService.setModoTeste(novoValor);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  novoValor
                                      ? '🧪 Modo Teste ativado! Relatórios irão para a pasta de homologação.'
                                      : '✅ Modo Teste desativado. Relatórios irão para a pasta oficial.',
                                ),
                                backgroundColor: novoValor ? AppColors.amber : AppColors.green,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // 8. Bloquear Caixa
                  _itemMenuCard(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFF1E3A8A).withOpacity(0.4),
                    titulo: 'Bloquear Caixa',
                    subtitulo: 'Travar tela por ausência do operador',
                    onTap: () => _bloquearCaixa(context),
                  ),
                  const SizedBox(height: 8),

                  // 9. Alterar PIN de Segurança do Operador
                  _itemMenuCard(
                    icon: Icons.password_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0369A1).withOpacity(0.4),
                    titulo: 'Alterar PIN de Segurança',
                    subtitulo: 'Atualizar senha individual do operador ${widget.turno?.operador ?? ""}',
                    onTap: () => _abrirTrocarPin(context),
                  ),
                  const SizedBox(height: 8),

                  // 10. Fechar Caixa & Resumo
                  _itemMenuCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBg: const Color(0xFF312E81).withOpacity(0.4),
                    titulo: 'Fechar Caixa & Resumo',
                    subtitulo: 'Conferir totais, conciliação e encerrar',
                    onTap: widget.onAbrirResumo,
                  ),
                  const SizedBox(height: 8),

                  // 11. Histórico de Turnos
                  _itemMenuCard(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    iconBg: const Color(0xFF164E63).withOpacity(0.4),
                    titulo: 'Histórico de Turnos',
                    subtitulo: 'Consultar ou reabrir turnos anteriores',
                    onTap: () => _abrirHistoricoTurnos(context),
                  ),
                  const SizedBox(height: 8),

                  // 12. Alternar Tema Claro / Escuro
                  _itemMenuCard(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
                    iconBg: isDark ? const Color(0xFF78350F).withOpacity(0.4) : const Color(0xFFDBEAFE),
                    titulo: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
                    subtitulo: isDark ? 'Mudar interface para fundo claro' : 'Mudar interface para modo noturno',
                    onTap: () => widget.onMudarTema(!isDark),
                  ),
                  const SizedBox(height: 8),

                  // 13. Trocar / Sair do Operador
                  _itemMenuCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Trocar / Sair do Operador',
                    subtitulo: 'Manter turno aberto e desconectar usuário',
                    onTap: widget.onAbrirNovoTurno,
                  ),
                  const SizedBox(height: 8),

                  // 14. Limpar / Zerar Tudo (Destaque Vermelho)
                  _itemMenuCard(
                    icon: Icons.delete_forever_rounded,
                    iconColor: const Color(0xFFEF4444),
                    iconBg: const Color(0xFF7F1D1D).withOpacity(0.4),
                    titulo: 'Limpar / Zerar Tudo',
                    subtitulo: 'Reset completo e irreversível dos dados',
                    corBorda: const Color(0xFF7F1D1D).withOpacity(0.6),
                    corTitulo: const Color(0xFFF87171),
                    onTap: () => _limparZerarTudo(context),
                  ),
                  const SizedBox(height: 18),

                  // Botão Fechar Menu
                  Center(
                    child: TextButton(
                      onPressed: () {
                        if (widget.onFechar != null) {
                          widget.onFechar!();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                      child: const Text(
                        'Fechar Menu',
                        style: TextStyle(color: Color(0xFF60A5FA), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemMenuCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    Color? corBorda,
    Color? corTitulo,
  }) {
    final cardBg = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;
    final cardBorder = corBorda ?? (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder);
    final titleCol = corTitulo ?? (isDark ? Colors.white : AppColors.lightTextPri);
    final subCol = isDark ? const Color(0xFF64748B) : AppColors.lightTextSec;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: titleCol,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 11, color: subCol),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subCol, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _itemMenuSwitch({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    final cardBg = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;
    final cardBorder = valor
        ? const Color(0xFFF59E0B).withOpacity(0.6)
        : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder);
    final titleCol = valor
        ? const Color(0xFFFBBF24)
        : (isDark ? Colors.white : AppColors.lightTextPri);
    final subCol = isDark ? const Color(0xFF64748B) : AppColors.lightTextSec;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: valor ? const Color(0xFF78350F).withOpacity(0.18) : cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder, width: valor ? 1.5 : 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleCol,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: subCol),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            activeColor: const Color(0xFFF59E0B),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
