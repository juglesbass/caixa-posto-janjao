import 'package:flutter/material.dart';
import '../services/database_service.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
    final bannerBorder = isDark ? const Color(0xFFD97706).withValues(alpha: 0.6) : const Color(0xFFFDE68A);
    final textTitle = isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
    final textSub = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bannerArmazenamento(isDark),
        _bannerPendencias(isDark, bannerBg, bannerBorder, textTitle, textSub),
      ],
    );
  }

  /// Alerta crítico: o banco abriu apenas em memória (falta o sqlite3.wasm no
  /// build web, ou o navegador bloqueou o armazenamento). Nada será salvo.
  Widget _bannerArmazenamento(bool isDark) {
    if (DatabaseService.armazenamentoPersistente) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.45) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARMAZENAMENTO INDISPONÍVEL',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Os lançamentos deste turno serão perdidos se o app for recarregado. Feche o turno o quanto antes e avise a gerência.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerPendencias(
    bool isDark,
    Color bannerBg,
    Color bannerBorder,
    Color textTitle,
    Color textSub,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.pendenciasCount,
      builder: (context, totalPendencias, _) {
        if (totalPendencias <= 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bannerBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalPendencias PDF(s) pendente(s) no Drive',
                      style: TextStyle(
                        color: textTitle,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Sem internet no momento do fechamento.',
                      style: TextStyle(
                        color: textSub,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
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
