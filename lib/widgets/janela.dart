import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';

// Peças comuns das janelas (diálogos e folhas de baixo).
//
// Cada janela antiga desenhava o próprio cabeçalho, os próprios botões e o
// próprio quadro de aviso, cada uma com um azul, um raio e um tamanho de letra
// diferentes. Com as mesmas peças, uma janela aberta pelo Menu tem a cara das
// que se abrem no Início — e o fundo e a borda vêm do tema, não de cada uma.

/// Cabeçalho de janela: ícone na cor da função, título, uma linha de apoio e,
/// se houver como fechar, o X.
class CabecalhoJanela extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onFechar;

  const CabecalhoJanela({
    super.key,
    required this.icone,
    required this.cor,
    required this.titulo,
    this.subtitulo,
    this.onFechar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    return Row(
      children: [
        IconeJanela(icone: icone, cor: cor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitulo!,
                  style: TextStyle(fontSize: AppTexto.rotulo, color: textSec, height: 1.3),
                ),
              ],
            ],
          ),
        ),
        if (onFechar != null)
          IconButton(
            icon: Icon(Icons.close_rounded, color: textSec),
            tooltip: 'Fechar',
            onPressed: onFechar,
          ),
      ],
    );
  }
}

/// O quadrado com o ícone na cor da função — o mesmo das linhas do Menu e do
/// Resumo.
class IconeJanela extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final double tamanho;

  const IconeJanela({super.key, required this.icone, required this.cor, this.tamanho = 36});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Icon(icone, color: cor, size: tamanho * 0.56),
    );
  }
}

/// Título de janela simples (AlertDialog), no mesmo tamanho do cabeçalho.
class TituloJanela extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final Color? cor;

  const TituloJanela(this.texto, {super.key, this.icone, this.cor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final titulo = Text(
      texto,
      style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
    );
    if (icone == null) return titulo;
    return Row(
      children: [
        Icon(icone, color: cor ?? AppColors.accentLight, size: 22),
        const SizedBox(width: 10),
        Expanded(child: titulo),
      ],
    );
  }
}

/// Texto corrido de uma janela.
class TextoJanela extends StatelessWidget {
  final String texto;

  const TextoJanela(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      texto,
      style: TextStyle(
        fontSize: AppTexto.corpo,
        color: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
        height: 1.4,
      ),
    );
  }
}

/// A ação principal de uma janela: cheia, 48pt de altura, a única colorida.
class BotaoPrincipal extends StatelessWidget {
  final String texto;
  final IconData? icone;
  final VoidCallback? onPressed;
  final Color cor;

  /// Mostra um giro no lugar do ícone, enquanto a ação trabalha.
  final bool ocupado;

  const BotaoPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icone,
    this.cor = AppColors.accent,
    this.ocupado = false,
  });

  @override
  Widget build(BuildContext context) {
    // Âmbar é claro demais para letra branca.
    final corTexto = cor == AppColors.amber ? Colors.black : Colors.white;
    final rotulo = Text(
      texto,
      style: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w700, color: corTexto),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final estilo = ElevatedButton.styleFrom(
      backgroundColor: cor,
      foregroundColor: corTexto,
      disabledBackgroundColor: cor.withValues(alpha: 0.5),
      disabledForegroundColor: corTexto.withValues(alpha: 0.8),
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
    );

    if (ocupado) {
      return ElevatedButton.icon(
        onPressed: null,
        style: estilo,
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: corTexto),
        ),
        label: rotulo,
      );
    }
    if (icone == null) {
      return ElevatedButton(onPressed: onPressed, style: estilo, child: rotulo);
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: estilo,
      icon: Icon(icone, size: 18, color: corTexto),
      label: rotulo,
    );
  }
}

/// A saída sem compromisso (Cancelar, Voltar): só texto, na cor secundária.
class BotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotaoSecundario({super.key, required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: isDark ? AppColors.darkTextSec : AppColors.lightTextSec,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Rodapé de janela: a saída à esquerda e a ação principal, mais larga, à
/// direita — como em "Corrigir lançamento".
class BotoesJanela extends StatelessWidget {
  final Widget secundario;
  final Widget principal;

  const BotoesJanela({super.key, required this.secundario, required this.principal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: secundario),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: principal),
      ],
    );
  }
}

/// Quadro de aviso tingido na cor do assunto: âmbar para pendência, vermelho
/// para perigo, verde para confirmação.
class AvisoJanela extends StatelessWidget {
  final Color cor;
  final IconData icone;
  final String? titulo;
  final String texto;

  /// Algo à direita do texto, como um botão.
  final Widget? fim;

  /// Letra e folga menores, para aviso que fica numa tela de trabalho (o de
  /// pendência no Início) e não numa janela.
  final bool compacto;

  const AvisoJanela({
    super.key,
    required this.cor,
    required this.icone,
    this.titulo,
    required this.texto,
    this.fim,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    // No fundo claro, âmbar e verde puros quase somem como letra: o título
    // escurece um pouco, o ícone e a borda ficam na cor do assunto.
    final corTitulo = isDark ? cor : Color.lerp(cor, Colors.black, 0.35)!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compacto ? 12 : 14, vertical: compacto ? 8 : 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: cor.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titulo != null) ...[
                  Text(
                    titulo!,
                    style: TextStyle(fontSize: AppTexto.corpo - 1, fontWeight: FontWeight.w800, color: corTitulo),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: compacto ? AppTexto.rotulo : AppTexto.rotulo + 1,
                    color: textPri,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (fim != null) ...[
            const SizedBox(width: 10),
            fim!,
          ],
        ],
      ),
    );
  }
}
