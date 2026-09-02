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
import 'gerencia/gestao_operadores_screen.dart';

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
  bool get isDark => widget.isDark;
  final _controllerPinMestre = TextEditingController();

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

  void _solicitarAcessoGerencia(BuildContext context) {
    _controllerPinMestre.clear();
    String? erroLocal;
    bool validandoLocal = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                  width: 1.2,
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
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Área Restrita da Gerência',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: textPri,
                          ),
                        ),
                        Text(
                          'Informe o PIN Mestre (4 dígitos)',
                          style: TextStyle(fontSize: 11, color: textSec),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Digite a senha administrativa para acessar o painel restrito de configurações e segurança:',
                    style: TextStyle(fontSize: 12.5, color: textSec, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controllerPinMestre,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 24,
                      letterSpacing: 10,
                      fontWeight: FontWeight.w900,
                      color: textPri,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      errorText: erroLocal,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.8),
                      ),
                    ),
                    onSubmitted: (_) => _validarEEntrarGerencia(
                      dialogCtx,
                      setDialogState,
                      (err) => erroLocal = err,
                      (v) => validandoLocal = v,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancelar', style: TextStyle(color: textSec)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: validandoLocal
                      ? null
                      : () => _validarEEntrarGerencia(
                            dialogCtx,
                            setDialogState,
                            (err) => erroLocal = err,
                            (v) => validandoLocal = v,
                          ),
                  icon: validandoLocal
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Acessar Painel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _validarEEntrarGerencia(
    BuildContext dialogCtx,
    StateSetter setDialogState,
    void Function(String?) setErro,
    void Function(bool) setValidando,
  ) async {
    final pin = _controllerPinMestre.text.trim();
    if (pin.length != 4) {
      setDialogState(() => setErro('Informe os 4 dígitos do PIN'));
      return;
    }
    setDialogState(() {
      setValidando(true);
      setErro(null);
    });

    final ok = await AuthService.validarPinGerente(pin);
    if (!dialogCtx.mounted) return;

    if (!ok) {
      AppHaptics.heavy();
      setDialogState(() {
        setValidando(false);
        setErro('PIN Mestre Incorreto!');
      });
      _controllerPinMestre.clear();
      return;
    }

    AppHaptics.light();
    Navigator.of(dialogCtx).pop();
    _controllerPinMestre.clear();

    if (mounted) {
      _abrirPainelGerencia(context);
    }
  }

  void _abrirPainelGerencia(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _PainelGerenciaPage(
          isDark: widget.isDark,
          turno: widget.turno,
          totais: widget.totais,
          onAlterarPinMestre: () => _abrirAlterarPinMestre(ctx),
          onGestaoOperadores: () => _abrirGestaoOperadores(ctx),
          onAnalytics: () => _abrirAnalytics(ctx),
          onExportarCsv: () => _exportarCsv(ctx),
          onLimparZerarTudo: () => _limparZerarTudo(ctx),
        ),
      ),
    );
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

  void _abrirGestaoOperadores(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => GestaoOperadoresScreen(isDark: widget.isDark),
      ),
    );
  }

  Widget _cardAreaGerencia(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1C1917), const Color(0xFF292524)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.8 : 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AppHaptics.light();
            _solicitarAcessoGerencia(context);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Área da Gerência',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'RESTRITO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configurações administrativas e segurança',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFD6D3D1) : const Color(0xFF78716C),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Barra Superior com Ícone de Menu e Fechar ──
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
                    child: const Icon(Icons.widgets_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu de Ações',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPri,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Operações do caixa e atalhos rápidos',
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (widget.onFechar != null)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSec),
                      onPressed: widget.onFechar,
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: borderCol),

            // ── Lista de Opções do Menu ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // ── 1. CARD DESTACADO NO TOPO: ÁREA DA GERÊNCIA (PIN MESTRE) ──
                  _cardAreaGerencia(context, isDark),
                  const SizedBox(height: 16),

                  // ── 2. RECURSOS OPERACIONAIS DA PISTA ──
                  Row(
                    children: [
                      Text(
                        'OPERAÇÕES DO CAIXA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: textSec,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 1. Sangria de Caixa
                  _itemMenuCard(
                    icon: Icons.north_east_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFF7C2D12).withOpacity(0.4),
                    titulo: 'Sangria de Caixa',
                    subtitulo: 'Registrar retirada de dinheiro para o cofre',
                    onTap: () => _abrirSangria(context),
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

                  // 3. Tabela de Códigos / Produtos
                  _itemMenuCard(
                    icon: Icons.shopping_bag_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0C4A6E).withOpacity(0.4),
                    titulo: 'Tabela de Códigos / Produtos',
                    subtitulo: 'Consulta rápida por código ou nome do produto',
                    onTap: () => _abrirConsultaProdutos(context),
                  ),
                  const SizedBox(height: 8),

                  // 4. Bloquear Caixa
                  _itemMenuCard(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFF1E3A8A).withOpacity(0.4),
                    titulo: 'Bloquear Caixa',
                    subtitulo: 'Travar tela por ausência do operador',
                    onTap: () => _bloquearCaixa(context),
                  ),
                  const SizedBox(height: 8),

                  // 5. Sincronizar com Google Drive
                  _itemMenuCard(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFF064E3B).withOpacity(0.4),
                    titulo: 'Sincronizar com Google Drive',
                    subtitulo: 'Forçar reenvio de relatórios pendentes na fila',
                    onTap: () => _sincronizarDrive(context),
                  ),
                  const SizedBox(height: 8),

                  // 6. Alterar Meu PIN
                  _itemMenuCard(
                    icon: Icons.password_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0369A1).withOpacity(0.4),
                    titulo: 'Alterar Meu PIN',
                    subtitulo: 'Atualizar senha individual do operador ${widget.turno?.operador ?? ""}',
                    onTap: () => _abrirTrocarPin(context),
                  ),
                  const SizedBox(height: 16),

                  // ── 3. ATALHOS GERAIS ──
                  Row(
                    children: [
                      Text(
                        'ATALHOS & APLICATIVO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: textSec,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fechar Caixa & Resumo
                  _itemMenuCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBg: const Color(0xFF312E81).withOpacity(0.4),
                    titulo: 'Fechar Caixa & Resumo',
                    subtitulo: 'Conferir totais, conciliação e encerrar',
                    onTap: widget.onAbrirResumo,
                  ),
                  const SizedBox(height: 8),

                  // Histórico de Turnos
                  _itemMenuCard(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    iconBg: const Color(0xFF164E63).withOpacity(0.4),
                    titulo: 'Histórico de Turnos',
                    subtitulo: 'Consultar ou reabrir turnos anteriores',
                    onTap: () => _abrirHistoricoTurnos(context),
                  ),
                  const SizedBox(height: 8),

                  // Alternar Tema Claro / Escuro
                  _itemMenuCard(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
                    iconBg: isDark ? const Color(0xFF78350F).withOpacity(0.4) : const Color(0xFFDBEAFE),
                    titulo: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
                    subtitulo: isDark ? 'Mudar interface para fundo claro' : 'Mudar interface para modo noturno',
                    onTap: () => widget.onMudarTema(!isDark),
                  ),
                  const SizedBox(height: 8),

                  // Trocar / Sair do Operador
                  _itemMenuCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Trocar / Sair do Operador',
                    subtitulo: 'Manter turno aberto e desconectar usuário',
                    onTap: widget.onAbrirNovoTurno,
                  ),
                  const SizedBox(height: 20),

                  if (widget.onFechar != null)
                    Center(
                      child: TextButton(
                        onPressed: widget.onFechar,
                        child: const Text(
                          'Voltar ao Caixa',
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

class _PainelGerenciaPage extends StatelessWidget {
  final bool isDark;
  final Turno? turno;
  final TotaisTurno totais;
  final VoidCallback onAlterarPinMestre;
  final VoidCallback onGestaoOperadores;
  final VoidCallback onAnalytics;
  final VoidCallback onExportarCsv;
  final VoidCallback onLimparZerarTudo;

  const _PainelGerenciaPage({
    required this.isDark,
    required this.turno,
    required this.totais,
    required this.onAlterarPinMestre,
    required this.onGestaoOperadores,
    required this.onAnalytics,
    required this.onExportarCsv,
    required this.onLimparZerarTudo,
  });

  @override
  Widget build(BuildContext context) {
    final bgScaffold = isDark ? const Color(0xFF090D16) : AppColors.lightBg;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Painel da Gerência',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPri,
                  ),
                ),
              ],
            ),
            Text(
              'Configurações administrativas e segurança',
              style: TextStyle(fontSize: 11, color: textSec, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderCol),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Alterar PIN Mestre da Gerência
          _itemGerenciaCard(
            icon: Icons.key_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFF78350F).withOpacity(0.4),
            titulo: 'Alterar PIN Mestre da Gerência',
            subtitulo: 'Modificar a senha administrativa mestre (SHA-256)',
            onTap: onAlterarPinMestre,
          ),
          const SizedBox(height: 10),

          // 2. Gestão de Operadores & Senhas
          _itemGerenciaCard(
            icon: Icons.badge_rounded,
            iconColor: const Color(0xFF38BDF8),
            iconBg: const Color(0xFF0369A1).withOpacity(0.4),
            titulo: 'Gestão de Operadores & Senhas',
            subtitulo: 'Visualizar operadores cadastrados e redefinir PINs',
            onTap: onGestaoOperadores,
          ),
          const SizedBox(height: 10),

          // 3. Analytics & Desempenho
          _itemGerenciaCard(
            icon: Icons.auto_graph_rounded,
            iconColor: const Color(0xFFA855F7),
            iconBg: const Color(0xFF581C87).withOpacity(0.4),
            titulo: 'Analytics & Desempenho',
            subtitulo: 'Gráficos de vendas, ticket médio e formas de pagamento',
            onTap: onAnalytics,
          ),
          const SizedBox(height: 10),

          // 4. Exportar Planilha Excel (CSV)
          _itemGerenciaCard(
            icon: Icons.table_chart_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFF064E3B).withOpacity(0.4),
            titulo: 'Exportar Planilha Excel (CSV)',
            subtitulo: 'Salvar ou compartilhar dados estruturados',
            onTap: onExportarCsv,
          ),
          const SizedBox(height: 10),

          // 5. Modo Teste / Simulação (Toggle)
          ValueListenableBuilder<bool>(
            valueListenable: DriveService.modoTesteNotifier,
            builder: (context, modoTeste, _) {
              final cardBg = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;
              final cardBorder = modoTeste
                  ? const Color(0xFFF59E0B).withOpacity(0.6)
                  : (isDark ? const Color(0xFF1E293B) : AppColors.lightBorder);
              final titleCol = modoTeste
                  ? const Color(0xFFFBBF24)
                  : (isDark ? Colors.white : AppColors.lightTextPri);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: modoTeste ? const Color(0xFF78350F).withOpacity(0.18) : cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder, width: modoTeste ? 1.5 : 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF78350F).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.science_outlined, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modo Teste / Simulação',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: titleCol,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Envia os relatórios para a pasta de homologação no Drive',
                            style: TextStyle(fontSize: 11, color: textSec),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: modoTeste,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (novoValor) async {
                        await DriveService.setModoTeste(novoValor);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                novoValor
                                    ? '🧪 Modo Teste ativado! Relatórios irão para a homologação.'
                                    : '✅ Modo Teste desativado. Relatórios irão para a pasta oficial.',
                              ),
                              backgroundColor: novoValor ? AppColors.amber : AppColors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // 6. Limpar / Zerar Tudo
          _itemGerenciaCard(
            icon: Icons.delete_forever_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFF7F1D1D).withOpacity(0.4),
            titulo: 'Limpar / Zerar Tudo',
            subtitulo: 'Reset completo e irreversível dos dados locais',
            corBorda: const Color(0xFF7F1D1D).withOpacity(0.6),
            corTitulo: const Color(0xFFF87171),
            onTap: onLimparZerarTudo,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _itemGerenciaCard({
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
                    maxLines: 2,
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
}
