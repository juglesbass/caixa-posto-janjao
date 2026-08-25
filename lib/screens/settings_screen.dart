import 'package:flutter/material.dart';
import '../dialogs/analytics_dialog.dart';
import '../dialogs/bloqueio_dialog.dart';
import '../dialogs/encerrantes_dialog.dart';
import '../dialogs/reset_dialog.dart';
import '../dialogs/sangria_dialog.dart';
import '../dialogs/turnos_anteriores_dialog.dart';
import '../models/totais_turno.dart';
import '../models/turno.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
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

  void _abrirEncerrantes(BuildContext context) {
    if (turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => EncerrantesDialog(turnoId: turno!.id!),
    );
  }

  void _abrirSangria(BuildContext context) async {
    if (turno == null) return;
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SangriaDialog(dinheiroNaGaveta: totais.dinheiroGaveta),
    );

    if (res != null) {
      final db = DatabaseService.instance;
      await db.inserirLancamento(
        turno!.id!,
        'Sangria',
        res['valor'] as double,
        res['motivo'] as String,
      );
      onRecarregar();
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
    if (turno == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AnalyticsDialog(turno: turno!, totais: totais),
    );
  }

  void _exportarCsv(BuildContext context) async {
    if (turno == null) return;
    try {
      final db = DatabaseService.instance;
      final lancamentos = await db.obterLancamentos(turno!.id!);
      await CsvService.exportarECompartilharCsv(
        turno: turno!,
        totais: totais,
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
      onRecarregar();
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
    if (turno == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BloqueioDialog(operador: turno!.operador),
    );
  }

  void _abrirHistoricoTurnos(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => TurnosAnterioresDialog(
        onReabrirTurno: (turnoReaberto) async {
          final db = DatabaseService.instance;
          await db.reabrirTurno(turnoReaberto.id!);
          onRecarregar();
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
          onRecarregar();
          onAbrirNovoTurno();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Menu do Caixa',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Gerenciamento e ações do turno',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      if (onFechar != null) {
                        onFechar!();
                      } else {
                        Navigator.maybePop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E293B)),

            // ── Lista de Opções do Menu ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: [
                  // 1. Encerrantes de Bombas
                  _itemMenuCard(
                    icon: Icons.local_gas_station_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Encerrantes de Bombas',
                    subtitulo: 'Conferência de litros vendidos nos bicos',
                    onTap: () => _abrirEncerrantes(context),
                  ),
                  const SizedBox(height: 8),

                  // 2. Sangria de Caixa
                  _itemMenuCard(
                    icon: Icons.north_east_rounded,
                    iconColor: const Color(0xFFEA580C),
                    iconBg: const Color(0xFF7C2D12).withOpacity(0.4),
                    titulo: 'Sangria de Caixa',
                    subtitulo: 'Registrar retirada de dinheiro para o cofre',
                    onTap: () => _abrirSangria(context),
                  ),
                  const SizedBox(height: 8),

                  // 3. Analytics & Desempenho
                  _itemMenuCard(
                    icon: Icons.auto_graph_rounded,
                    iconColor: const Color(0xFFA855F7),
                    iconBg: const Color(0xFF581C87).withOpacity(0.4),
                    titulo: 'Analytics & Desempenho',
                    subtitulo: 'Gráficos de vendas e horários de pico',
                    onTap: () => _abrirAnalytics(context),
                  ),
                  const SizedBox(height: 8),

                  // 4. Exportar para Excel (CSV)
                  _itemMenuCard(
                    icon: Icons.table_chart_rounded,
                    iconColor: const Color(0xFF0D9488),
                    iconBg: const Color(0xFF134E4A).withOpacity(0.4),
                    titulo: 'Exportar para Excel (CSV)',
                    subtitulo: 'Baixar relatório financeiro formatado para Excel',
                    onTap: () => _exportarCsv(context),
                  ),
                  const SizedBox(height: 8),

                  // 5. Sincronizar Google Drive
                  _itemMenuCard(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFF0C4A6E).withOpacity(0.4),
                    titulo: 'Sincronizar Google Drive',
                    subtitulo: 'Reenviar relatórios e PDFs pendentes para o Drive',
                    onTap: () => _sincronizarDrive(context),
                  ),
                  const SizedBox(height: 8),

                  // 6. Bloquear Caixa
                  _itemMenuCard(
                    icon: Icons.lock_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFF1E3A8A).withOpacity(0.4),
                    titulo: 'Bloquear Caixa',
                    subtitulo: 'Travar tela por ausência do operador',
                    onTap: () => _bloquearCaixa(context),
                  ),
                  const SizedBox(height: 8),

                  // 7. Fechar Caixa & Resumo
                  _itemMenuCard(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBg: const Color(0xFF312E81).withOpacity(0.4),
                    titulo: 'Fechar Caixa & Resumo',
                    subtitulo: 'Conferir totais, conciliação e encerrar',
                    onTap: onAbrirResumo,
                  ),
                  const SizedBox(height: 8),

                  // 8. Histórico de Turnos
                  _itemMenuCard(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    iconBg: const Color(0xFF164E63).withOpacity(0.4),
                    titulo: 'Histórico de Turnos',
                    subtitulo: 'Consultar ou reabrir turnos anteriores',
                    onTap: () => _abrirHistoricoTurnos(context),
                  ),
                  const SizedBox(height: 8),

                  // 9. Trocar / Sair do Operador
                  _itemMenuCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Trocar / Sair do Operador',
                    subtitulo: 'Manter turno aberto e desconectar usuário',
                    onTap: onAbrirNovoTurno,
                  ),
                  const SizedBox(height: 8),

                  // 10. Limpar / Zerar Tudo (Destaque Vermelho)
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
                        if (onFechar != null) {
                          onFechar!();
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131C2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: corBorda ?? const Color(0xFF1E293B)),
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
                      color: corTitulo ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
          ],
        ),
      ),
    );
  }
}
