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
                        'Menu do Caixa',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: textPri,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Gerenciamento e ações do turno',
                        style: TextStyle(fontSize: 11, color: textSec),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSec),
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
            Divider(height: 1, color: borderCol),

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
                    subtitulo: 'Gráficos de vendas, ticket médio e formas',
                    onTap: () => _abrirAnalytics(context),
                  ),
                  const SizedBox(height: 8),

                  // 4. Exportar Planilha Excel (CSV)
                  _itemMenuCard(
                    icon: Icons.table_chart_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFF064E3B).withOpacity(0.4),
                    titulo: 'Exportar Planilha Excel (CSV)',
                    subtitulo: 'Salvar ou compartilhar dados estruturados',
                    onTap: () => _exportarCsv(context),
                  ),
                  const SizedBox(height: 8),

                  // 5. Sincronizar com Google Drive
                  _itemMenuCard(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    iconBg: const Color(0xFF0C4A6E).withOpacity(0.4),
                    titulo: 'Sincronizar com Google Drive',
                    subtitulo: 'Forçar reenvio de relatórios pendentes na fila',
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

                  // 9. Alternar Tema Claro / Escuro
                  _itemMenuCard(
                    icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    iconColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF2563EB),
                    iconBg: isDark ? const Color(0xFF78350F).withOpacity(0.4) : const Color(0xFFDBEAFE),
                    titulo: isDark ? 'Ativar Tema Claro' : 'Ativar Tema Escuro',
                    subtitulo: isDark ? 'Mudar interface para fundo claro' : 'Mudar interface para modo noturno',
                    onTap: () => onMudarTema(!isDark),
                  ),
                  const SizedBox(height: 8),

                  // 10. Trocar / Sair do Operador
                  _itemMenuCard(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFF78350F).withOpacity(0.4),
                    titulo: 'Trocar / Sair do Operador',
                    subtitulo: 'Manter turno aberto e desconectar usuário',
                    onTap: onAbrirNovoTurno,
                  ),
                  const SizedBox(height: 8),

                  // 11. Limpar / Zerar Tudo (Destaque Vermelho)
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
}
