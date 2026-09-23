import 'package:flutter/material.dart';
import '../models/motivo_pendencia.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import 'janela.dart';

class PendingSyncBanner extends StatefulWidget {
  final VoidCallback? onSincronizado;

  /// Espaco em volta do aviso. O padrao deixa folga dos lados para as telas
  /// em que ele encosta na borda; a tela Inicio ja tem a propria margem e
  /// passa zero dos lados, senao o aviso ficava mais estreito que os cartoes.
  final EdgeInsets margem;

  const PendingSyncBanner({
    super.key,
    this.onSincronizado,
    this.margem = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bannerArmazenamento(),
        _bannerPendencias(),
      ],
    );
  }

  /// Alerta crítico: o banco abriu apenas em memória (falta o sqlite3.wasm no
  /// build web, ou o navegador bloqueou o armazenamento). Nada será salvo.
  Widget _bannerArmazenamento() {
    if (DatabaseService.armazenamentoPersistente) return const SizedBox.shrink();

    return Padding(
      padding: widget.margem,
      child: const AvisoJanela(
        cor: AppColors.red,
        icone: Icons.warning_amber_rounded,
        titulo: 'Armazenamento indisponível',
        compacto: true,
        texto: 'Os lançamentos deste turno serão perdidos se o app for recarregado. '
            'Feche o turno o quanto antes e avise a gerência.',
      ),
    );
  }

  Widget _bannerPendencias() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.pendenciasCount,
      builder: (context, totalPendencias, _) {
        if (totalPendencias <= 0) return const SizedBox.shrink();

        return Padding(
          padding: widget.margem,
          // O texto vem da causa gravada com a pendência: antes era fixo em
          // "sem internet", o que mentia quando a falha era timeout com rede
          // boa, erro do servidor ou tela de login.
          child: ValueListenableBuilder<String?>(
            valueListenable: NotificationService.motivoPendencia,
            builder: (context, motivo, _) => AvisoJanela(
              cor: AppColors.amber,
              icone: Icons.cloud_off_rounded,
              titulo: '$totalPendencias PDF(s) pendente(s) no Drive',
              texto: MotivoPendencia.descricao(motivo),
              compacto: true,
              fim: _sincronizando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
                    )
                  : ElevatedButton(
                      onPressed: () => _sincronizar(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      child: const Text(
                        'Reenviar',
                        style: TextStyle(fontSize: AppTexto.rotulo + 1, fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
