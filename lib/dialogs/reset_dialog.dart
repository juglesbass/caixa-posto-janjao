import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';

class ResetDialog extends StatelessWidget {
  final VoidCallback onResetConcluido;

  const ResetDialog({super.key, required this.onResetConcluido});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
          SizedBox(width: 10),
          Text(
            'Limpar / Zerar Tudo?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      content: const Text(
        'ATENÇÃO: Esta ação apagará permanentemente todos os turnos, lançamentos e histórico deste dispositivo.\n\n'
        'Esta operação é irreversível. Deseja realmente zerar todo o banco de dados?',
        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
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
