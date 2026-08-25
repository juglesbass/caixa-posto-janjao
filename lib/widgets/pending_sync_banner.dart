import 'package:flutter/material.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class PendingSyncBanner extends StatefulWidget {
  final VoidCallback? onSincronizado;

  const PendingSyncBanner({super.key, this.onSincronizado});

  @override
  State<PendingSyncBanner> createState() => _PendingSyncBannerState();
}

class _PendingSyncBannerState extends State<PendingSyncBanner> {
  bool _sincronizando = false;

  Future<void> _sincronizar(BuildContext context) async {
    setState(() => _sincronizando = true);

    final res = await DriveService.sincronizarTodasPendencias();

    if (mounted) {
      setState(() => _sincronizando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensagem),
          backgroundColor: res.todosOk ? AppColors.green : AppColors.amber,
          duration: const Duration(seconds: 4),
        ),
      );

      if (res.todosOk && widget.onSincronizado != null) {
        widget.onSincronizado!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.pendenciasCount,
      builder: (context, totalPendencias, _) {
        if (totalPendencias <= 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF78350F).withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD97706).withOpacity(0.6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPendencias PDF(s) pendente(s) no Drive',
                      style: const TextStyle(
                        color: Color(0xFFFDE68A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'Sem internet no momento do fechamento.',
                      style: TextStyle(
                        color: Color(0xFFFCD34D),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (_sincronizando)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFBBF24),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _sincronizar(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text(
                    'Reenviar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
