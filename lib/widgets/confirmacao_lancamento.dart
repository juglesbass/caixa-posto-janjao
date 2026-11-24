import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';

/// Notificação flutuante discreta no topo da tela confirmando um lançamento.
///
/// Fica no topo (abaixo da barra de status/AppBar) para nunca disputar espaço
/// com a barra inferior nem ficar escondida atrás do teclado virtual no PWA,
/// Android ou iOS. Se outro lançamento entrar antes de a anterior sumir,
/// substitui imediatamente sem empilhar avisos antigos.
class ConfirmacaoLancamento {
  ConfirmacaoLancamento._();

  static OverlayEntry? _entradaAtual;
  static Timer? _timerAtual;

  /// Exibe a confirmação: "R$ X,XX lançado em <forma de pagamento>".
  static void mostrar(
    BuildContext context, {
    required double valor,
    required String tipo,
    Duration duracao = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    fechar();

    final valorFormatado = CurrencyFormatter.formatar(valor);
    final cor = AppColors.getCorTipo(tipo);
    final icone = AppIcones.doTipo(tipo);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _BannerConfirmacaoLancamento(
        valorFormatado: valorFormatado,
        tipo: tipo,
        cor: cor,
        icone: icone,
        onFechar: () {
          if (_entradaAtual == entry) {
            fechar();
          }
        },
      ),
    );

    _entradaAtual = entry;
    overlay.insert(entry);
    _timerAtual = Timer(duracao, () {
      if (_entradaAtual == entry) {
        fechar();
      }
    });
  }

  /// Remove imediatamente a notificação ativa, se houver.
  static void fechar() {
    _timerAtual?.cancel();
    _timerAtual = null;
    try {
      _entradaAtual?.remove();
    } catch (_) {}
    _entradaAtual = null;
  }
}

class _BannerConfirmacaoLancamento extends StatefulWidget {
  final String valorFormatado;
  final String tipo;
  final Color cor;
  final IconData icone;
  final VoidCallback onFechar;

  const _BannerConfirmacaoLancamento({
    required this.valorFormatado,
    required this.tipo,
    required this.cor,
    required this.icone,
    required this.onFechar,
  });

  @override
  State<_BannerConfirmacaoLancamento> createState() =>
      _BannerConfirmacaoLancamentoState();
}

class _BannerConfirmacaoLancamentoState
    extends State<_BannerConfirmacaoLancamento>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final cor = isDark && widget.cor == AppColors.purple
        ? AppColors.purpleLight
        : widget.cor;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onFechar,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
                          border: Border.all(
                            color: cor.withValues(alpha: isDark ? 0.65 : 0.55),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.14),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: isDark ? 0.22 : 0.14),
                                borderRadius: BorderRadius.circular(AppColors.radiusXs),
                              ),
                              child: Icon(widget.icone, size: 17, color: cor),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: widget.valorFormatado,
                                      style: TextStyle(
                                        fontSize: AppTexto.corpo,
                                        fontWeight: FontWeight.w800,
                                        color: textPri,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' lançado em ',
                                      style: TextStyle(
                                        fontSize: AppTexto.corpo,
                                        fontWeight: FontWeight.w500,
                                        color: textSec,
                                      ),
                                    ),
                                    TextSpan(
                                      text: widget.tipo,
                                      style: TextStyle(
                                        fontSize: AppTexto.corpo,
                                        fontWeight: FontWeight.w800,
                                        color: cor,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
