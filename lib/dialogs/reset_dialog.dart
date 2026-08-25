import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class ResetDialog extends StatelessWidget {
  final VoidCallback onResetConcluido;

  const ResetDialog({super.key, required this.onResetConcluido});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgDialog = isDark ? const Color(0xFF0F172A) : AppColors.lightSurface;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFFCBD5E1) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    return AlertDialog(
      backgroundColor: bgDialog,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderCol),
      ),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
          const SizedBox(width: 10),
          Text(
            'Limpar / Zerar Tudo?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPri),
          ),
        ],
      ),
      content: Text(
        'ATENÇÃO: Esta ação apagará permanentemente todos os turnos, lançamentos e histórico deste dispositivo.\n\n'
        'Esta operação é irreversível. Deseja realmente zerar todo o banco de dados?',
        style: TextStyle(color: textSec, fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec)),
        ),
        ElevatedButton(
          onPressed: () async {
            final db = DatabaseService.instance;
            await db.resetarTudo();
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ Todos os dados foram zerados com sucesso!'),
                  backgroundColor: AppColors.red,
                ),
              );
              onResetConcluido();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sim, Zerar Tudo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
