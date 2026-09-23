import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';

/// Um passo do envio do fechamento: gravar, gerar o PDF, mandar ao Drive.
typedef PassoFechamento = ({
  String titulo,
  String subtitulo,
  IconData icone,
  Color corTema,
  bool carregando,
});

/// Janela que acompanha o encerramento do turno, passo a passo. Não fecha por
/// toque nem pelo voltar: quem a fecha é o próprio encerramento, ao terminar.
class ProgressoFechamentoDialog extends StatelessWidget {
  final ValueListenable<PassoFechamento> passo;

  const ProgressoFechamentoDialog({super.key, required this.passo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: ValueListenableBuilder<PassoFechamento>(
            valueListenable: passo,
            builder: (context, estado, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(estado.titulo),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: estado.corTema.withValues(alpha: isDark ? 0.16 : 0.12),
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (estado.carregando)
                            SizedBox.expand(
                              child: CircularProgressIndicator(color: estado.corTema, strokeWidth: 3),
                            ),
                          Icon(estado.icone, color: estado.corTema, size: estado.carregando ? 26 : 34),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      estado.titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: estado.carregando ? textPri : estado.corTema,
                        fontWeight: FontWeight.w800,
                        fontSize: AppTexto.valor + 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      estado.subtitulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSec, fontSize: AppTexto.corpo, height: 1.4),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
